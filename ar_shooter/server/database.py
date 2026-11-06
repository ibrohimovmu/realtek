import json
import os
import sqlite3
import time
from typing import List, Optional, Tuple

DB_PATH = os.path.join(os.path.dirname(__file__), "ar_shooter.db")


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS players (
                name TEXT PRIMARY KEY,
                xp INTEGER NOT NULL DEFAULT 0,
                kills INTEGER NOT NULL DEFAULT 0,
                deaths INTEGER NOT NULL DEFAULT 0,
                region TEXT NOT NULL DEFAULT 'Toshkent',
                badges TEXT NOT NULL DEFAULT '[]',
                last_seen INTEGER NOT NULL
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS rooms (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                host_ip TEXT NOT NULL,
                port INTEGER NOT NULL DEFAULT 4040,
                mode TEXT NOT NULL DEFAULT 'Team Deathmatch',
                map TEXT NOT NULL DEFAULT 'Taktik Arena',
                player_count INTEGER NOT NULL DEFAULT 1,
                last_ping INTEGER NOT NULL
            )
            """
        )
        conn.commit()


def upsert_player(name: str, xp: int, kills: int, deaths: int, region: str, badges: List[str]) -> Tuple[int, int]:
    now = int(time.time())
    badges_json = json.dumps(badges)

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO players (name, xp, kills, deaths, region, badges, last_seen)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(name) DO UPDATE SET
                xp = MAX(players.xp, excluded.xp),
                kills = MAX(players.kills, excluded.kills),
                deaths = MAX(players.deaths, excluded.deaths),
                region = excluded.region,
                badges = excluded.badges,
                last_seen = excluded.last_seen
            """,
            (name, xp, kills, deaths, region, badges_json, now),
        )
        conn.commit()

        # Calculate global rank by XP
        cursor.execute("SELECT COUNT(*) FROM players WHERE xp > (SELECT xp FROM players WHERE name = ?)", (name,))
        higher_count = cursor.fetchone()[0]
        rank = higher_count + 1

        cursor.execute("SELECT COUNT(*) FROM players")
        total = cursor.fetchone()[0]

        return rank, total


def get_leaderboard(limit: int = 50) -> List[dict]:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT name, xp, kills, deaths, region, badges
            FROM players
            ORDER BY xp DESC, kills DESC
            LIMIT ?
            """,
            (limit,),
        )
        rows = cursor.fetchall()
        result = []
        for idx, row in enumerate(rows):
            try:
                b_list = json.loads(row["badges"])
            except Exception:
                b_list = []
            result.append(
                {
                    "rank": idx + 1,
                    "name": row["name"],
                    "xp": row["xp"],
                    "kills": row["kills"],
                    "deaths": row["deaths"],
                    "region": row["region"],
                    "badges_count": len(b_list),
                }
            )
        return result


def announce_room(name: str, host_ip: str, port: int, mode: str, map_name: str, player_count: int) -> str:
    room_id = f"{host_ip}:{port}"
    now = int(time.time())

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO rooms (id, name, host_ip, port, mode, map, player_count, last_ping)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                player_count = excluded.player_count,
                mode = excluded.mode,
                map = excluded.map,
                last_ping = excluded.last_ping
            """,
            (room_id, name, host_ip, port, mode, map_name, player_count, now),
        )
        conn.commit()
        return room_id


def get_active_rooms(timeout_seconds: int = 60) -> List[dict]:
    now = int(time.time())
    threshold = now - timeout_seconds

    with get_connection() as conn:
        cursor = conn.cursor()
        # Delete dead rooms
        cursor.execute("DELETE FROM rooms WHERE last_ping < ?", (threshold,))
        conn.commit()

        cursor.execute(
            """
            SELECT id, name, host_ip, port, mode, map, player_count, last_ping
            FROM rooms
            ORDER BY last_ping DESC
            """
        )
        rows = cursor.fetchall()
        return [dict(row) for row in rows]
