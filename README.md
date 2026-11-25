# FieldLink

FieldLink is an offline-first messaging app for teams working in areas with limited connectivity. Nearby devices can exchange messages and media directly, and users can send SOS reports to a triage service when a network connection is available.

## Features

- Discover nearby devices and exchange messages over local connections.
- Send encrypted messages and share media.
- Create SOS reports and optionally forward them to the triage service.
- Buffer reports on the device while the service is unreachable.

## Run the app

Install [Flutter](https://docs.flutter.dev/get-started/install), then run:

```sh
flutter pub get
flutter run
```

## Optional triage service

The Python service classifies incoming reports and keeps an in-memory priority queue. To run it:

```sh
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python triage_server.py
```

The service listens on port `8000` by default. Set the `PORT` environment variable to use another port. API documentation is available at `/docs`.

Configure the service URL in the app's gateway settings. Devices must be able to reach the service over the network; local device-to-device messaging does not require the service.

## Project layout

- `lib/`: Flutter app source.
- `test/`: Flutter tests.
- `triage_server.py`: optional Python triage API.
- `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`: Flutter platform projects.
