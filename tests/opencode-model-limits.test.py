import importlib.util
import sys

spec = importlib.util.spec_from_file_location("limits", sys.argv[1])
limits = importlib.util.module_from_spec(spec)
spec.loader.exec_module(limits)
catalog = {
    "openai": {
        "models": {
            "new-model": {
                "limit": {"context": 1050000, "input": 922000, "output": 128000}
            }
        }
    },
    "anthropic": {
        "models": {"new-claude": {"limit": {"context": 1000000, "output": 128000}}}
    },
}
meridian = {"data": [{"id": "new-claude", "context_window": 200000}]}
models = [
    {
        "providerID": "openai",
        "id": "new-model-fast",
        "modelID": "new-model",
        "limit": {"context": 400000, "input": 272000, "output": 128000},
    },
    {
        "providerID": "anthropic",
        "id": "new-claude",
        "modelID": "new-claude",
        "limit": {"context": 200000, "output": 128000},
    },
]
assert len(limits.audit(models, catalog, meridian)[1]) == 1, (
    "detect ChatGPT caps through model aliases"
)
models[0]["limit"] = catalog["openai"]["models"]["new-model"]["limit"]
assert not limits.audit(models, catalog, meridian)[1], (
    "preserve subscription-specific context"
)
models[1]["limit"]["input"] = 10000
assert len(limits.audit(models, catalog, meridian)[1]) == 1, (
    "detect stale input budgets"
)
del models[1]["limit"]["input"]
models[0]["modelID"] = "unlisted-model"
assert "needs review" in limits.audit(models, catalog, meridian)[1][0]
print("Model-limit audit regression tests passed")
