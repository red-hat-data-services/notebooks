from tests.containers import conftest


def is_rstudio_image(my_image: str) -> bool:
    label = "-rstudio-"

    image_metadata = conftest.get_image_metadata(my_image)

    return label in image_metadata.labels["name"]


def is_codeserver_image(my_image: str) -> bool:
    name = conftest.get_image_metadata(my_image).labels.get("name", "")

    return "-code-server-" in name or "-codeserver-" in name
