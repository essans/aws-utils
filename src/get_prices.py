

# -----------------------------------------------------------------------------
# Wrapper script for EC2 on-demand prices
#
# Uses the aws pricing API to get hourly prices for a given instance type and region/location. 
# Not designed to be used directly, instead it is called by higher-level scripts such 
# as ec2_specs_price.py.
#
# Main functions:
#   - ondemand1: Basic price lookup for a given instance type/location
#   - ondemand2: More robust price lookup, filtering out zero-priced and
#                capacity block SKUs, with pagination and extra safety checks
#
# -----------------------------------------------------------------------------


import json
from decimal import Decimal, InvalidOperation
from typing import Any

def ondemand1(
    pricing_client: Any,
    instance_type: str,
    location: str,
    operating_system: str = "Linux",
    tenancy: str = "Shared",
    preinstalled_sw: str = "NA",
    capacity_status: str = "Used",
    license_model: str = "No License required"
    ) -> float | None:
    
    # Query pricing api
    # Pass region_name="us-east-1" to pricing Api.
    try:
        resp = pricing_client.get_products(
            ServiceCode="AmazonEC2",
            Filters=[
                {"Type": "TERM_MATCH", "Field": "instanceType", "Value": instance_type},
                {"Type": "TERM_MATCH", "Field": "location", "Value": location},
                {"Type": "TERM_MATCH", "Field": "operatingSystem", "Value": operating_system},
                {"Type": "TERM_MATCH", "Field": "tenancy", "Value": tenancy},
                {"Type": "TERM_MATCH", "Field": "preInstalledSw", "Value": preinstalled_sw},
                {"Type": "TERM_MATCH", "Field": "capacitystatus", "Value": capacity_status},
                {"Type": "TERM_MATCH", "Field": "licenseModel", "Value": license_model},
            ],
            MaxResults=100,
        )
    except Exception:
        return None

    # Each PriceList item is a big JSON string; pull the first valid OnDemand price dimension.
    for pl in resp.get("PriceList", []):
        try:
            # PriceList is a JSON string; boto3 returns it as dict already in recent versions; handle both.
            item = pl if isinstance(pl, dict) else __import__("json").loads(pl)

            terms = item.get("terms", {}).get("OnDemand", {})
            for _, term in terms.items():
                price_dims = term.get("priceDimensions", {})
                for _, dim in price_dims.items():
                    if dim.get("unit") == "Hrs":
                        usd_str = dim.get("pricePerUnit", {}).get("USD")
                        if usd_str is not None:
                            return float(usd_str)
        except Exception:
            continue

    return None


def ondemand2(
    pricing_client: Any,
    instance_type: str,
    location: str,
    operating_system: str = "Linux",
    tenancy: str = "Shared",
    preinstalled_sw: str = "NA",
    capacity_status: str = "Used",
    license_model: str = "No License required",
    ) -> float | None:
    """
    Returns the USD hourly On-Demand price for an EC2 instance type in a given Pricing 'location'
    (e.g. 'US East (N. Virginia)'). This *excludes* Capacity Block SKUs and ignores zero-priced
    placeholders.

    NOTE: Create the client in us-east-1 for the Pricing API:
        boto3.client("pricing", region_name="us-east-1")
    """
    # Base filters: standard Linux, shared tenancy, no preinstalled SW, used capacity, license-free
    base_filters = [
        {"Type": "TERM_MATCH", "Field": "instanceType",   "Value": instance_type},
        {"Type": "TERM_MATCH", "Field": "location",       "Value": location},
        {"Type": "TERM_MATCH", "Field": "operatingSystem","Value": operating_system},
        {"Type": "TERM_MATCH", "Field": "tenancy",        "Value": tenancy},
        {"Type": "TERM_MATCH", "Field": "preInstalledSw", "Value": preinstalled_sw},
        {"Type": "TERM_MATCH", "Field": "capacitystatus", "Value": capacity_status},
        {"Type": "TERM_MATCH", "Field": "licenseModel",   "Value": license_model},
        # These two lines are the key to avoid Capacity Blocks / $0.00 entries:
        {"Type": "TERM_MATCH", "Field": "operation",      "Value": "RunInstances"},
        {"Type": "TERM_MATCH", "Field": "marketoption",   "Value": "OnDemand"},
    ]

    next_token = None

    try:
        while True:
            kwargs = {
                "ServiceCode": "AmazonEC2",
                "Filters": base_filters,
                "MaxResults": 100,
            }
            if next_token:
                kwargs["NextToken"] = next_token

            resp = pricing_client.get_products(**kwargs)

            # Each PriceList item is usually a JSON string; normalize to dict
            for pl in resp.get("PriceList", []):
                item = pl if isinstance(pl, dict) else json.loads(pl)

                # Extra safety: double-check attributes (in case filters evolve)
                attrs = item.get("product", {}).get("attributes", {}) or {}
                if attrs.get("operation") != "RunInstances":
                    continue
                if (attrs.get("marketoption") or "OnDemand") != "OnDemand":
                    continue
                if attrs.get("capacitystatus") not in (None, "", "Used"):
                    # Ignore odd entries like UnusedCapacityReservation, etc.
                    continue

                # Walk OnDemand → priceDimensions → pricePerUnit.USD
                terms = item.get("terms", {}).get("OnDemand", {}) or {}
                for term in terms.values():
                    pds = (term.get("priceDimensions") or {})
                    for pd in pds.values():
                        if pd.get("unit") != "Hrs":
                            continue
                        usd = (pd.get("pricePerUnit") or {}).get("USD")
                        if not usd:
                            continue
                        try:
                            val = Decimal(usd)
                        except (InvalidOperation, TypeError):
                            continue
                        # Ignore zeros (placeholders should never pass our filters, but just in case)
                        if val > 0:
                            return float(val)

            # pagination
            next_token = resp.get("NextToken")
            if not next_token:
                break

    except Exception:
        return None

    return None