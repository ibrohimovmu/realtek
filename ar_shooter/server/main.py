from contextlib import asynccontextmanager
from typing import List
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

from database import announce_room, get_active_rooms, get_leaderboard, init_db, upsert_player
from models import (
    LeaderboardEntry,
    PlayerSyncRequest,
    PlayerSyncResponse,
    RoomAnnounceRequest,
    RoomEntry,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="AR Shooter Online Server",
    version="1.0.0",
    description="Dedicated lightweight backend for AR Shooter: Global Leaderboards, Player Stats, and Room Registry",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "version": "1.0.0",
        "game": "AR Shooter",
    }


@app.post("/api/stats/sync", response_model=PlayerSyncResponse)
def sync_player_stats(req: PlayerSyncRequest):
    rank, total = upsert_player(
        name=req.name,
        xp=req.xp,
        kills=req.kills,
        deaths=req.deaths,
        region=req.region,
        badges=req.badges,
    )
    return PlayerSyncResponse(
        status="synced",
        name=req.name,
        global_rank=rank,
        total_players=total,
    )


@app.get("/api/leaderboard", response_model=List[LeaderboardEntry])
def read_leaderboard(limit: int = Query(50, ge=1, le=100)):
    return get_leaderboard(limit=limit)


@app.post("/api/rooms/announce")
def register_room(req: RoomAnnounceRequest):
    room_id = announce_room(
        name=req.name,
        host_ip=req.host_ip,
        port=req.port,
        mode=req.mode,
        map_name=req.map,
        player_count=req.player_count,
    )
    return {
        "status": "announced",
        "room_id": room_id,
    }


@app.get("/api/rooms", response_model=List[RoomEntry])
def read_rooms():
    return get_active_rooms(timeout_seconds=60)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=7860, reload=True)
