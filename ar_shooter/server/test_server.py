import unittest
import os
import sys

# Ensure server module path is accessible
sys.path.insert(0, os.path.dirname(__file__))

from database import init_db, upsert_player, get_leaderboard, announce_room, get_active_rooms


class TestServerLogic(unittest.TestCase):
    def setUp(self):
        init_db()

    def test_upsert_and_leaderboard(self):
        rank1, total1 = upsert_player("OperatorAlpha", 1200, 15, 2, "Toshkent", ["first_blood"])
        self.assertGreaterEqual(rank1, 1)
        self.assertGreaterEqual(total1, 1)

        rank2, total2 = upsert_player("OperatorBravo", 2500, 30, 4, "Samarqand", ["first_blood", "marksman"])
        self.assertEqual(rank2, 1)  # Higher XP takes rank 1

        board = get_leaderboard(limit=10)
        self.assertGreaterEqual(len(board), 2)
        self.assertEqual(board[0]["name"], "OperatorBravo")

    def test_room_announcement_and_retrieval(self):
        room_id = announce_room(
            name="Alpha Squad",
            host_ip="192.168.1.50",
            port=4040,
            mode="Team Deathmatch",
            map_name="Taktik Arena",
            player_count=3,
        )
        self.assertEqual(room_id, "192.168.1.50:4040")

        rooms = get_active_rooms(timeout_seconds=60)
        self.assertTrue(any(r["id"] == "192.168.1.50:4040" for r in rooms))


if __name__ == "__main__":
    unittest.main()
