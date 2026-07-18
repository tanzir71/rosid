import unittest

from tool.audit_ios_privacy import find_forbidden_terms


class IosPrivacyAuditTest(unittest.TestCase):
    def test_rejects_mlkit_family_names_case_insensitively(self) -> None:
        for name in (
            "google_mlkit_text_recognition",
            "GoogleMLKit/TextRecognition",
            "MLKitCommon",
            "MLKitVision",
            "MLKitTextRecognition",
        ):
            with self.subTest(name=name):
                self.assertIn("mlkit", find_forbidden_terms(name))

    def test_rejects_transport_support_components(self) -> None:
        contents = "GoogleDataTransport\nGTMSessionFetcher/Core"
        matches = find_forbidden_terms(contents)
        self.assertIn("GoogleDataTransport", matches)
        self.assertIn("GTMSessionFetcher", matches)

    def test_allows_tesseract_only_resolution(self) -> None:
        contents = "Flutter\nflutter_tesseract_ocr\nSwiftyTesseract"
        self.assertEqual(find_forbidden_terms(contents), [])


if __name__ == "__main__":
    unittest.main()
