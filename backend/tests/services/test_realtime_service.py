"""Unit tests for realtime_service.py - determine_mode function."""

import pytest
from app.services.realtime_service import determine_mode


class TestDetermineMode:
    """Test mode determination from route_id heuristics."""

    def test_train_routes(self):
        """Test Sydney Trains route IDs."""
        assert determine_mode("T1") == "sydneytrains"
        assert determine_mode("T2") == "sydneytrains"
        assert determine_mode("T3") == "sydneytrains"
        assert determine_mode("T9") == "sydneytrains"
        assert determine_mode("BMT1") == "sydneytrains"
        assert determine_mode("BMT2") == "sydneytrains"

    def test_metro_routes(self):
        """Test Sydney Metro route IDs."""
        assert determine_mode("M1") == "metro"
        assert determine_mode("SMNW_M1") == "metro"

    def test_ferry_routes(self):
        """Test ferry route IDs (Sydney Ferries and MFF)."""
        assert determine_mode("F1") == "ferries"
        assert determine_mode("F2") == "ferries"
        assert determine_mode("F10") == "ferries"
        assert determine_mode("9-F1-sj2-1") == "ferries"
        assert determine_mode("9-F2-sj2-1") == "ferries"

        # MFF special case (must not be classified as metro)
        assert determine_mode("MFF") == "ferries"
        assert determine_mode("mff") == "ferries"  # case insensitive

    def test_lightrail_routes(self):
        """Test light rail route IDs."""
        assert determine_mode("L1") == "lightrail"
        assert determine_mode("IWLR-191") == "lightrail"

    def test_bus_routes(self):
        """Test bus route IDs (default fallback)."""
        assert determine_mode("199") == "buses"
        assert determine_mode("333") == "buses"
        assert determine_mode("890") == "buses"
        assert determine_mode("S1") == "buses"  # School bus
        assert determine_mode("2507_275") == "buses"
        assert determine_mode("N80") == "buses"  # Night bus

    def test_edge_cases(self):
        """Test edge cases and empty inputs."""
        assert determine_mode("") == "buses"
        assert determine_mode(None) == "buses"

    def test_case_insensitivity(self):
        """Test that mode detection is case insensitive."""
        assert determine_mode("t1") == "sydneytrains"
        assert determine_mode("f1") == "ferries"
        assert determine_mode("l1") == "lightrail"
        assert determine_mode("m1") == "metro"
