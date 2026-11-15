import os
from typing import Any, Literal

from pydantic import BaseModel, Field

import mistralai.workflows as workflows

API_BASE = "https://api.planets.nu"
API_KEY_ENV = "PLANETSNU_API_KEY"
_TIMEOUT_SECONDS = 120.0


class ApiResult(BaseModel):
    status_code: int
    body: Any = None
    text: str = ""


def _api_key() -> str:
    key = os.environ.get(API_KEY_ENV, "")
    if not key:
        raise RuntimeError(f"Missing environment variable {API_KEY_ENV}")
    return key


def _clean(params: dict[str, Any]) -> dict[str, str]:
    return {key: str(value) for key, value in params.items() if value is not None}


async def _request(
    method: str,
    path: str,
    *,
    params: dict[str, str] | None = None,
    data: dict[str, str] | None = None,
) -> ApiResult:
    import httpx

    async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
        response = await client.request(method, f"{API_BASE}{path}", params=params, data=data)
    try:
        body: Any = response.json()
    except ValueError:
        return ApiResult(status_code=response.status_code, body=None, text=response.text)
    return ApiResult(status_code=response.status_code, body=body)


@workflows.activity()
async def api_get(path: str, params: dict[str, Any] | None = None) -> ApiResult:
    return await _request("GET", path, params=_clean(params or {}))


@workflows.activity()
async def api_post_form(
    path: str,
    fields: dict[str, Any] | None = None,
    with_api_key: bool = False,
) -> ApiResult:
    data = _clean(fields or {})
    if with_api_key:
        data = {**data, "apikey": _api_key()}
    return await _request("POST", path, data=data)


class PlanetsApiInput(BaseModel):
    action: Literal["loadinfo", "loadturn", "save", "get", "post"]
    gameid: int | None = None
    playerid: int | None = None
    turn: int | None = None
    version: int | None = None
    savekey: str = ""
    saveindex: int | None = None
    path: str = ""
    params: dict[str, Any] = Field(default_factory=dict)
    fields: dict[str, Any] = Field(default_factory=dict)


@workflows.workflow.define(
    name="diana-planets-api",
    workflow_display_name="Diana planets.nu API",
    workflow_description="GET and POST access to the planets.nu API (loadinfo, loadturn, save).",
)
class PlanetsApiWorkflow:
    @workflows.workflow.entrypoint
    async def run(self, input: PlanetsApiInput) -> ApiResult:
        if input.action == "loadinfo":
            return await api_get("/game/loadinfo", {"gameid": input.gameid})
        if input.action == "loadturn":
            return await api_post_form(
                "/game/loadturn",
                {"gameid": input.gameid, "playerid": input.playerid},
                with_api_key=True,
            )
        if input.action == "save":
            data: dict[str, Any] = dict(input.fields)
            data.update(
                {
                    "gameid": input.gameid,
                    "playerid": input.playerid,
                    "turn": input.turn,
                    "version": input.version,
                    "savekey": input.savekey,
                    "saveindex": input.saveindex,
                }
            )
            return await api_post_form("/game/save", data, with_api_key=True)
        if input.action == "get":
            if not input.path.startswith("/"):
                return ApiResult(status_code=400, body=None, text="path must start with /")
            return await api_get(input.path, input.params)
        if not input.path.startswith("/game/"):
            return ApiResult(status_code=400, body=None, text="path must start with /game/")
        return await api_post_form(input.path, input.fields, with_api_key=True)
