"""Tests for the evaluation and benchmarking script."""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from evaluate import calculate_improvement, calculate_workload_balance, load_json_file


class TestLoadJsonFile:
    def test_load_valid_file(self, tmp_path):
        data = {"key": "value", "num": 42}
        f = tmp_path / "test.json"
        f.write_text(json.dumps(data))
        result = load_json_file(str(f))
        assert result == data

    def test_load_nonexistent_file(self):
        result = load_json_file("/nonexistent/path/file.json")
        assert result is None

    def test_load_invalid_json(self, tmp_path):
        f = tmp_path / "bad.json"
        f.write_text("not valid json {{{")
        result = load_json_file(str(f))
        assert result is None

    def test_load_list(self, tmp_path):
        data = [1, 2, 3]
        f = tmp_path / "list.json"
        f.write_text(json.dumps(data))
        result = load_json_file(str(f))
        assert result == data


class TestCalculateImprovement:
    def test_positive_improvement(self):
        result = calculate_improvement(100, 80)
        assert result == 20.0

    def test_no_improvement(self):
        result = calculate_improvement(100, 100)
        assert result == 0.0

    def test_zero_baseline(self):
        result = calculate_improvement(0, 50)
        assert result == 0

    def test_negative_improvement(self):
        result = calculate_improvement(100, 120)
        assert result == -20.0

    def test_large_improvement(self):
        result = calculate_improvement(200, 50)
        assert result == 75.0

    def test_small_values(self):
        result = calculate_improvement(10, 9)
        assert abs(result - 10.0) < 0.01


class TestCalculateWorkloadBalance:
    def test_balanced_workload(self):
        technicians = [
            {"technician_id": "T1", "max_daily_hours": 8},
            {"technician_id": "T2", "max_daily_hours": 8},
        ]
        routes = {
            "T1": [
                {"estimated_duration_minutes": 120},
                {"estimated_duration_minutes": 120},
            ],
            "T2": [
                {"estimated_duration_minutes": 120},
                {"estimated_duration_minutes": 120},
            ],
        }
        result = calculate_workload_balance(routes, technicians)
        assert result["hours_stdev"] == 0.0
        assert result["stops_stdev"] == 0.0
        assert result["hours_mean"] == 4.0
        assert result["stops_mean"] == 2.0

    def test_unbalanced_workload(self):
        technicians = [
            {"technician_id": "T1", "max_daily_hours": 8},
            {"technician_id": "T2", "max_daily_hours": 8},
        ]
        routes = {
            "T1": [
                {"estimated_duration_minutes": 360},
            ],
            "T2": [
                {"estimated_duration_minutes": 60},
            ],
        }
        result = calculate_workload_balance(routes, technicians)
        assert result["hours_stdev"] > 0
        assert result["stops_stdev"] == 0.0  # Both have 1 stop

    def test_single_technician(self):
        technicians = [{"technician_id": "T1", "max_daily_hours": 8}]
        routes = {
            "T1": [{"estimated_duration_minutes": 240}],
        }
        result = calculate_workload_balance(routes, technicians)
        assert result["hours_stdev"] == 0
        assert result["hours_mean"] == 4.0

    def test_empty_routes(self):
        technicians = [
            {"technician_id": "T1", "max_daily_hours": 8},
            {"technician_id": "T2", "max_daily_hours": 8},
        ]
        routes = {"T1": [], "T2": []}
        result = calculate_workload_balance(routes, technicians)
        assert result["hours_mean"] == 0
        assert result["stops_mean"] == 0
