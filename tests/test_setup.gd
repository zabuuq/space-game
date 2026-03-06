extends GutTest

func test_framework_setup():
	assert_true(true, "This test should always pass, indicating GUT is set up properly.")

func test_math():
	var result = 2 + 2
	assert_eq(result, 4, "Basic math works.")