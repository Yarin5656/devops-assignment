import unittest

from app.services.rickmorty import is_target_character


class RickMortyFilterTest(unittest.TestCase):
    def test_is_target_character_exact_earth(self):
        good = {
            "species": "Human",
            "status": "Alive",
            "origin": {"name": "Earth"},
        }
        bad_origin = {
            "species": "Human",
            "status": "Alive",
            "origin": {"name": "Earth (Replacement Dimension)"},
        }

        self.assertTrue(is_target_character(good))
        self.assertFalse(is_target_character(bad_origin))


if __name__ == "__main__":
    unittest.main()
