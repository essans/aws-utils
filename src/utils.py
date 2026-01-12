
# Some utilities I use across a number of projects

from pathlib import Path
import yaml
from typing import Any
from types import SimpleNamespace


def get_project_root() -> Path:
    """
    Return the absolute path to the project root directory by walking parents
    until a marker file/directory (e.g., ``pyproject.toml``) is found.
    """
    path = Path().absolute()
    markers = ['data', 'src', 'notebooks', '.git', 'configs', 'scripts']

    while path != path.parent:
            if any((path / marker).exists() for marker in markers):
                return path
            path = path.parent
    
    print("Could not explicitly determine project root")
    return path.parent


def to_namespace(obj: dict[str, Any]) -> SimpleNamespace:
    """
    Helper function to convert attributes into a class-like namespace
    """
    if isinstance(obj, dict):
        ns = SimpleNamespace()
        for key, value in obj.items():
            setattr(ns, key, to_namespace(value))
        return ns
    if isinstance(obj, list):
        return [to_namespace(item) for item in obj]
    return obj


def yaml_to_dict(filepath: str|Path) -> dict[str, Any]:
        """
        Reads a YAML file and returns data in form of dictionary.
        """
        try:
            with open(filepath, "r") as f:
                return yaml.safe_load(f) or {}
        except FileNotFoundError:
            print('config file: {filepath} not found!')
            return {}


def configs_from_yaml(path: Path | str = "configs/settings.yaml") -> SimpleNamespace:
        root = get_project_root()
        if root is None:
            raise RuntimeError('Unable to determine project root directory.')
        return to_namespace(yaml_to_dict(root / path))


