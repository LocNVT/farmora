class_name FailingSaveFileIO extends SaveFileIO

## Test double that lets a test force write_atomic() to fail
## deterministically, without needing real disk-full conditions. Exists for
## SaveService retry/backoff tests (a later task). Never used by production
## code.

var fail_write: bool = false

func write_atomic(json_text: String) -> Error:
	if fail_write:
		return ERR_CANT_CREATE
	return super.write_atomic(json_text)
