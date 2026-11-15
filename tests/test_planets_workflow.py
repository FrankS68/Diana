import pytest
import respx
from httpx import Response

from worker.workflows.planets import API_KEY_ENV, PlanetsApiInput, PlanetsApiWorkflow, api_get, api_post_form

TASK_QUEUE = "test-task-queue"


@pytest.fixture
def api_key(monkeypatch):
    monkeypatch.setenv(API_KEY_ENV, "test-key")


@respx.mock
@pytest.mark.asyncio
async def test_loadinfo_sends_gameid(temporal_env, api_key):
    route = respx.get("https://api.planets.nu/game/loadinfo").mock(
        return_value=Response(200, json={"game": {"id": 689819, "status": 1}})
    )
    async with create_worker(temporal_env):
        result = await run_workflow(temporal_env, PlanetsApiInput(action="loadinfo", gameid=689819))
    assert result["status_code"] == 200
    assert result["body"]["game"]["id"] == 689819
    assert route.called


@respx.mock
@pytest.mark.asyncio
async def test_loadturn_adds_api_key_and_hides_it(temporal_env, api_key):
    route = respx.post("https://api.planets.nu/game/loadturn").mock(
        return_value=Response(200, json={"ok": True})
    )
    async with create_worker(temporal_env):
        result = await run_workflow(
            temporal_env,
            PlanetsApiInput(action="loadturn", gameid=689819, playerid=9),
        )
    assert result["status_code"] == 200
    assert result["body"] == {"ok": True}
    request_content = route.calls.last.request.content.decode()
    assert "apikey=test-key" in request_content
    assert "gameid=689819" in request_content
    assert "playerid=9" in request_content
    assert "test-key" not in str(result)


@respx.mock
@pytest.mark.asyncio
async def test_save_merges_fields_and_params(temporal_env, api_key):
    route = respx.post("https://api.planets.nu/game/save").mock(
        return_value=Response(200, json={"saved": True})
    )
    async with create_worker(temporal_env):
        result = await run_workflow(
            temporal_env,
            PlanetsApiInput(
                action="save",
                gameid=689819,
                playerid=9,
                turn=3,
                version=1,
                savekey="abc",
                saveindex=2,
                fields={"Planet123": "{\"ownerid\":9}", "keycount": "1"},
            ),
        )
    assert result["status_code"] == 200
    request_content = route.calls.last.request.content.decode()
    assert "Planet123=" in request_content
    assert "keycount=1" in request_content
    assert "savekey=abc" in request_content
    assert "version=1" in request_content


@respx.mock
@pytest.mark.asyncio
async def test_missing_api_key_fails(temporal_env, monkeypatch):
    monkeypatch.delenv(API_KEY_ENV, raising=False)
    respx.post("https://api.planets.nu/game/loadturn").mock(
        return_value=Response(200, json={})
    )
    async with create_worker(temporal_env):
        with pytest.raises(Exception):
            await run_workflow(temporal_env, PlanetsApiInput(action="loadturn", gameid=1))


@respx.mock
@pytest.mark.asyncio
async def test_generic_post_rejects_foreign_paths(temporal_env, api_key):
    async with create_worker(temporal_env):
        result = await run_workflow(
            temporal_env, PlanetsApiInput(action="post", path="/other/endpoint")
        )
    assert result["status_code"] == 400


def create_worker(env):
    from mistralai.workflows.testing import create_test_worker

    return create_test_worker(env, [PlanetsApiWorkflow], activities=[api_get, api_post_form])


async def run_workflow(env, input_data):
    handle = await env.client.start_workflow(
        PlanetsApiWorkflow.run,
        input_data,
        id="diana-planets-api-test",
        task_queue=TASK_QUEUE,
    )
    return await handle.result()
