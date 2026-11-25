import platform
import os
from typing import Optional, Union, List, Dict, Any
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Example data used to initialize the lightweight triage model.
training_data = [
    ("Trapped under collapsed concrete, 2 people bleeding heavily, need immediate rescue", "Entrapment", 1),
    ("Severe head trauma, unconscious breathing shallowly, send medics", "Medical", 1),
    ("Hospital oxygen cylinders running out, 5 patients critical", "Medical", 1),
    ("Rising flood waters reached 2nd floor, family stranded on roof", "Entrapment", 2),
    ("Water supply contaminated, 50 people need drinking water", "Supplies", 2),
    ("Bridge collapsed at crossing, road blocked, no casualties", "Infrastructure", 3),
    ("Power lines down on main avenue, sparking danger", "Infrastructure", 3),
    ("We have moved to high school shelter, everyone safe here", "Safe", 5),
    ("Cell service is fluctuating, just checking in", "Safe", 5),
]

df = pd.DataFrame(training_data, columns=['text', 'category', 'urgency'])

# Train a classifier for report urgency.
urgency_clf = Pipeline([
    ('tfidf', TfidfVectorizer(ngram_range=(1, 2))),
    ('clf', LogisticRegression(max_iter=1000))
])
urgency_clf.fit(df['text'], df['urgency'])

# Train a classifier for report category.
cat_clf = Pipeline([
    ('tfidf', TfidfVectorizer(ngram_range=(1, 2))),
    ('clf', LogisticRegression(max_iter=1000))
])
cat_clf.fit(df['text'], df['category'])

app = FastAPI(
    title="FieldLink Triage Service",
    description="Classifies SOS reports by category and urgency.",
    version="1.0.0"
)

# Enable CORS for browser access from local development workstations
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class SOSPayload(BaseModel):
    device_id: Optional[str] = "rescue_node"
    text: str
    lat: Optional[float] = 0.0
    lng: Optional[float] = 0.0
    location: Optional[Dict[str, float]] = None
    priority: Optional[int] = None
    timestamp: Optional[str] = None

dispatch_queue = []

@app.get("/")
def root():
    return {
        "message": "FieldLink triage service is running",
        "architecture": platform.machine(),
        "system": platform.system(),
        "release": platform.release(),
        "active_queue_count": len(dispatch_queue),
        "docs_url": "/docs"
    }

@app.get("/api/system/info")
def system_info():
    """Return service status and current queue counts."""
    p1 = sum(1 for item in dispatch_queue if item.get('priority_level') == 1)
    p2 = sum(1 for item in dispatch_queue if item.get('priority_level') == 2)
    p3 = sum(1 for item in dispatch_queue if item.get('priority_level') in (3, 4, 5))
    
    return {
        "platform_machine": platform.machine(),
        "system_os": platform.system(),
        "os_release": platform.release(),
        "python_version": platform.python_version(),
        "active_queue_len": len(dispatch_queue),
        "total_ingested": len(dispatch_queue),
        "p1_critical_count": p1,
        "p2_severe_count": p2,
        "p3_general_count": p3
    }

@app.post("/api/triage/stream")
async def process_sos(payload: Union[SOSPayload, List[SOSPayload], Dict[str, Any], List[Dict[str, Any]]]):
    """
    Ingests SOS distress reports, performs real-time NLP classification,
    and sorts the emergency dispatch queue by urgency.
    Supports individual reports and batched sync from FieldLink clients.
    """
    items = []
    if isinstance(payload, list):
        for p in payload:
            if isinstance(p, SOSPayload):
                items.append(p)
            elif isinstance(p, dict):
                items.append(SOSPayload(**p))
    elif isinstance(payload, SOSPayload):
        items.append(payload)
    elif isinstance(payload, dict):
        items.append(SOSPayload(**payload))

    last_record = None

    for item in items:
        # Extract location coordinates flexibly
        lat = item.lat
        lng = item.lng
        if (lat == 0.0 or lat is None) and item.location:
            lat = item.location.get("lat", 0.0)
            lng = item.location.get("lng", 0.0)

        # Predict urgency level (1 = Critical, 5 = Safe)
        predicted_urgency = int(urgency_clf.predict([item.text])[0])
        predicted_category = str(cat_clf.predict([item.text])[0])

        triage_record = {
            "device_id": item.device_id or "rescue_node",
            "text": item.text,
            "category": predicted_category,
            "priority_level": predicted_urgency,
            "lat": lat,
            "lng": lng,
            "processed_by": "FieldLink Triage Service"
        }

        dispatch_queue.append(triage_record)
        dispatch_queue.sort(key=lambda x: x['priority_level'])
        last_record = triage_record

    return {
        "status": "success",
        "triage": last_record or {},
        "current_queue_length": len(dispatch_queue)
    }

@app.get("/api/triage/queue")
def get_queue():
    return {"queue": dispatch_queue}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    print(f"Starting FieldLink Triage Service on 0.0.0.0:{port}...")
    uvicorn.run(app, host="0.0.0.0", port=port)
