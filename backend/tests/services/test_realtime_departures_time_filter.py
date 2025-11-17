import re

import pytest

from app.services import realtime_service


class _FakeResult:
    def __init__(self, data):
        self.data = data
        self.count = len(data)

    def execute(self):
        return self


class _FakeSupabase:
    def __init__(self, sample_dep):
        self.sample_dep = sample_dep

    def rpc(self, name, params):
        assert name == "exec_raw_sql"
        query = params["query"]
        match = re.search(r"departure_offset_secs >= (\d+)", query)
        assert match, "threshold not found in query"
        threshold = int(match.group(1))
        if threshold <= self.sample_dep["departure_offset_secs"]:
            return _FakeResult([self.sample_dep])
        return _FakeResult([])


class _FakeRedis:
    def get(self, key):
        return None


@pytest.fixture
def sample_departure():
    return {
        "trip_id": "T123",
        "trip_headsign": "Test dest",
        "direction_id": 0,
        "wheelchair_accessible": 1,
        "route_id": "T1",
        "route_short_name": "T1",
        "route_long_name": "City",
        "route_type": 2,
        "route_color": "123456",
        "departure_offset_secs": 29400,  # 08:10:00 local
        "stop_sequence": 5,
    }


@pytest.fixture(autouse=True)
def patch_clients(monkeypatch, sample_departure):
    monkeypatch.setattr(realtime_service, "get_supabase", lambda: _FakeSupabase(sample_departure))
    monkeypatch.setattr(realtime_service, "get_redis_binary", lambda: _FakeRedis())


def test_departures_returned_when_time_before_offset(sample_departure):
    deps = realtime_service.get_realtime_departures(
        stop_id="STOP1",
        time_secs_local=8 * 3600,  # 08:00:00
        service_date="2024-04-01",
        limit=5,
    )

    assert len(deps) == 1
    assert deps[0]["trip_id"] == sample_departure["trip_id"]


def test_departures_filtered_when_time_after_offset():
    deps = realtime_service.get_realtime_departures(
        stop_id="STOP1",
        time_secs_local=18 * 3600,  # 18:00:00
        service_date="2024-04-01",
        limit=5,
    )

    assert deps == []
