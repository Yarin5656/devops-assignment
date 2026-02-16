import importlib.util
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKER_PATH = ROOT / "worker" / "worker.py"

spec = importlib.util.spec_from_file_location("task2_worker", WORKER_PATH)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


def test_parse_feature_collection():
    payload = {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [1, 2]},
                "properties": {"name": "p1"},
            }
        ],
    }
    features = worker.parse_geojson(json.dumps(payload))
    assert len(features) == 1
    assert features[0]["properties"]["name"] == "p1"


def test_parse_feature():
    payload = {
        "type": "Feature",
        "geometry": {"type": "Point", "coordinates": [0, 0]},
        "properties": {},
    }
    features = worker.parse_geojson(json.dumps(payload))
    assert len(features) == 1


def test_parse_invalid_type_raises():
    payload = {"type": "Polygon"}
    try:
        worker.parse_geojson(json.dumps(payload))
        assert False, "Expected ValueError"
    except ValueError:
        assert True