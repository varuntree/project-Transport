"""Departures Page Model - Architecture Decoupling.

DeparturesPage encapsulates departures response with source tracking
to enable RT-only mode (Layer 2↔3 independence).

Per Oracle guidance: Backend should serve RT departures even when
Supabase (Layer 3) empty, using Redis (Layer 2) as standalone source.
"""

from typing import List, Dict, Optional
from pydantic import BaseModel


class DeparturesPage(BaseModel):
    """Departures page response with source metadata.

    Attributes:
        stop_exists: Whether stop found in any data source (Supabase OR Redis RT)
        source: Data source used (static+rt | rt_only | static_only | no_data)
        stale: Whether RT cache >90s old
        departures: List of departure dicts
        earliest_time_secs: Earliest departure time in results (for pagination)
        latest_time_secs: Latest departure time in results
        has_more_past: Whether more departures exist before earliest
        has_more_future: Whether more departures exist after latest
    """

    stop_exists: bool
    source: str  # static+rt | rt_only | static_only | no_data
    stale: bool
    departures: List[Dict]
    earliest_time_secs: Optional[int] = None
    latest_time_secs: Optional[int] = None
    has_more_past: bool = False
    has_more_future: bool = False

    def to_dict(self) -> Dict:
        """Convert to API envelope format.

        Returns:
            Dict matching BACKEND_SPECIFICATION.md Section 3.2 envelope:
            {
                "data": {
                    "departures": [...],
                    "earliest_time_secs": int | null,
                    "latest_time_secs": int | null,
                    "has_more_past": bool,
                    "has_more_future": bool
                },
                "meta": {
                    "source": str,
                    "stale": bool
                }
            }
        """
        return {
            "data": {
                "departures": self.departures,
                "earliest_time_secs": self.earliest_time_secs,
                "latest_time_secs": self.latest_time_secs,
                "has_more_past": self.has_more_past,
                "has_more_future": self.has_more_future
            },
            "meta": {
                "source": self.source,
                "stale": self.stale
            }
        }

    @classmethod
    def empty(cls, stop_id: str, stop_exists: bool) -> "DeparturesPage":
        """Create empty page for failure cases.

        Args:
            stop_id: Stop ID (for logging)
            stop_exists: Whether stop found in any source

        Returns:
            DeparturesPage with no_data source
        """
        return cls(
            stop_exists=stop_exists,
            source="no_data",
            stale=False,
            departures=[],
            earliest_time_secs=None,
            latest_time_secs=None,
            has_more_past=False,
            has_more_future=False
        )
