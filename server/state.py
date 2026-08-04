import asyncio

_predictor = None
_pipe = None
_request_counter = 0
_shutdown_event = asyncio.Event()

_device = "cpu"

