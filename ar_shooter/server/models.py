from typing import List, Optional
from pydantic import BaseModel, Field


class PlayerSyncRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=24)
    xp: int = Field(0, ge=0)
    kills: int = Field(0, ge=0)
    deaths: int = Field(0, ge=0)
    region: str = Field("Toshkent", max_length=32)
    badges: List[str] = Field(default_factory=list)


class PlayerSyncResponse(BaseModel):
    status: str
    name: str
    global_rank: int
    total_players: int


class LeaderboardEntry(BaseModel):
    rank: int
    name: str
    xp: int
    kills: int
    deaths: int
    region: str
    badges_count: int


class RoomAnnounceRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=48)
    host_ip: str
    port: int = Field(4040, ge=1, le=65535)
    mode: str = "Team Deathmatch"
    map: str = "Taktik Arena"
    player_count: int = Field(1, ge=1, le=32)


class RoomEntry(BaseModel):
    id: str
    name: str
    host_ip: str
    port: int
    mode: str
    map: str
    player_count: int
    last_ping: int
