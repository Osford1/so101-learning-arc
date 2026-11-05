# Demo: Code 1 streaming vs cached dataset — what actually gets pulled.
import torch
from lerobot.datasets.streaming_dataset import StreamingLeRobotDataset
from lerobot.datasets.lerobot_dataset import LeRobotDataset

def g(obj, name):
    try:
        v = getattr(obj, name)
        return v() if callable(v) else v
    except Exception:
        return "n/a"

print("=================== STREAMING (lazy, on-demand) ===================")
print("-> instantiating StreamingLeRobotDataset('lerobot/svla_so101_pickplace')...")
ds = StreamingLeRobotDataset("lerobot/svla_so101_pickplace")
print("num_episodes :", g(ds, "num_episodes"))
print("fps          :", g(ds, "fps"))

meta = g(ds, "meta")
print("meta type    :", type(meta).__name__)
for f in ("num_episodes", "fps", "total_frames", "features", "tasks"):
    print(f"  meta.{f:12s} :", g(meta, f) if not hasattr(g(meta, f), "keys") else list(g(meta, f).keys()))

print("\n-> consume a sample by ITERATING (the streaming way in 0.6.1):")
try:
    it = iter(ds)
    s = next(it)
    print("   got a sample! keys:", list(s.keys()) if isinstance(s, dict) else type(s).__name__)
    if isinstance(s, dict):
        for k, v in s.items():
            print(f"      {k}: {type(v).__name__} shape={tuple(v.shape) if hasattr(v,'shape') else repr(v)[:40]}")
except Exception as e:
    print("   iteration ->", repr(e)[:120])

print("\n===========================================================")
print("=================== CACHED (download once) ===================")
print("===========================================================")
print("-> instantiating LeRobotDataset(...) - downloads + caches to disk, supports ds[i]")
try:
    d = LeRobotDataset("lerobot/svla_so101_pickplace")
    print("num_episodes :", g(d, "num_episodes"), "| fps:", g(d, "fps"), "| total_frames:", g(d, "total_frames"))
    print("features     :", list(d.features.keys()))
    print("\n-> leaf = d[10]")
    sample = d[10]
    print("   sample keys:", list(sample.keys()))
    for k, v in sample.items():
        if hasattr(v, "shape"):
            print(f"      {k}: {type(v).__name__} shape={tuple(v.shape)} dtype={v.dtype}")
        else:
            print(f"      {k}: {repr(v)[:50]}")
    print("\nDemo OK: streaming = lazy metadata + iterate; cached = download then ds[i].")
except Exception as e:
    print("cached dataset ->", repr(e)[:200])
