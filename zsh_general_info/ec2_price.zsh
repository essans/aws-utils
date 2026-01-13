
# Function to fetch current on-demand pricing for EC2 instance types.  Assumes us-east-1
#
# - ec2_price <instance-type>: Simple price lookup for a given instance type.
# - ec2_price2 <instance-type>: More robust, parses raw json for accuracy.
# - ec2_price_raw <instance-type>: Outputs raw aws pricing json for inspection, trouble-shooting
#
# Usage:
#   ec2_price t3a.large
#   ec2_price2 g4dn.xlarge
#   ec2_price_raw m5a.2xlarge
#
# Requires jq package installed for json parsing
# 
# Designed and tested to work in mac zsh

ec2_price() {
  local itype="$1"
  if [[ -z "$itype" ]]; then
    echo "Usage: ec2_price <instance-type>" >&2
    return 1
  fi
    
  aws pricing get-products \
    --service-code AmazonEC2 \
    --filters "[
      {\"Type\":\"TERM_MATCH\",\"Field\":\"instanceType\",\"Value\":\"$itype\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"location\",\"Value\":\"US East (N. Virginia)\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"operatingSystem\",\"Value\":\"Linux\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"tenancy\",\"Value\":\"Shared\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"preInstalledSw\",\"Value\":\"NA\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"capacitystatus\",\"Value\":\"Used\"}
    ]" \
    --region us-east-1 \
    --query "PriceList[0]" \
    --output text \
    | jq -r '.terms.OnDemand[].priceDimensions[].pricePerUnit.USD'
}


#to take into account capacity blocks
ec2_price2() {
  local itype="$1"
  if [[ -z "$itype" ]]; then
    echo "Usage: ec2_price <instance-type>" >&2
    return 1
  fi

  aws pricing get-products \
    --region us-east-1 \
    --service-code AmazonEC2 \
    --filters "[
      {\"Type\":\"TERM_MATCH\",\"Field\":\"instanceType\",\"Value\":\"$itype\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"location\",\"Value\":\"US East (N. Virginia)\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"operatingSystem\",\"Value\":\"Linux\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"tenancy\",\"Value\":\"Shared\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"preInstalledSw\",\"Value\":\"NA\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"licenseModel\",\"Value\":\"No License required\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"capacitystatus\",\"Value\":\"Used\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"operation\",\"Value\":\"RunInstances\"},
      {\"Type\":\"TERM_MATCH\",\"Field\":\"marketoption\",\"Value\":\"OnDemand\"}
    ]" \
    --query 'PriceList' \
    --output json \
  | jq -r '
      .[]                           # iterate each JSON string
      | fromjson                    # turn it into an object
      # extra safety filters (in case the API returns mixed entries)
      | select((.product.attributes.operation // "") == "RunInstances")
      | select((.product.attributes.marketoption // "OnDemand") == "OnDemand")
      # dig into OnDemand → priceDimensions → USD
      | .terms.OnDemand
      | to_entries[]                # the single OnDemand term
      | .value.priceDimensions
      | to_entries[]                # usually one dimension
      | .value.pricePerUnit.USD
  ' | head -n1
}


ec2_price_raw() {
  local itype="$1"
  if [[ -z "$itype" ]]; then
    echo "Usage: ec2_price <instance-type>" >&2
    return 1
  fi


  aws pricing get-products \
    --region us-east-1 \
    --service-code AmazonEC2 \
    --filters \
      Type=TERM_MATCH,Field=instanceType,Value="$itype" \
      Type=TERM_MATCH,Field=location,Value="US East (N. Virginia)" \
      Type=TERM_MATCH,Field=tenancy,Value=Shared \
      Type=TERM_MATCH,Field=operatingSystem,Value=Linux \
      Type=TERM_MATCH,Field=preInstalledSw,Value=NA \
      Type=TERM_MATCH,Field=licenseModel,Value="No License required" \
      Type=TERM_MATCH,Field=capacitystatus,Value=Used \
      Type=TERM_MATCH,Field=operation,Value=RunInstances \
      Type=TERM_MATCH,Field=marketoption,Value=OnDemand \
    --query 'PriceList[0]'

}


