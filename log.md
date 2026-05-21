# CORRECT:

flutter: │ 💡   - Raw MetersPerPixel: 1.0
flutter: │ 💡   - Effective MetersPerPixel (unit: feet): 0.015240000000000002
flutter: └─────────────────────────────────────────────────
flutter: ┌─────────────────────────────────────────────────
flutter: │ 11:22:44.179 (+0:13:36.782331)
flutter: ├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
flutter: │ 💡 🏁 AR NAVIGATION POINT ZERO INITIALIZED!
flutter: │ 💡   - Origin AR Heading (Yaw): 90.0°
flutter: │ 💡   - Origin Position: (x: 0.00, y: -0.00, z: 0.00)
flutter: │ 💡   - Origin Confidence: 0.50
flutter: │ 💡   - API Reference Heading: 10.6°
flutter: │ 💡   - Initial Calculated sumHeadingDeg: 100.6°
flutter: └─────────────────────────────────────────────────
flutter: ┌─────────────────────────────────────────────────
flutter: │ 11:22:44.179 (+0:13:36.782722)
flutter: ├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
flutter: │ 💡 📍 AR First Localized Coordinates calculated:
flutter: │ 💡   - Raw Screen Coordinates: (x: 976.1, y: 754.7)
flutter: │ 💡   - Initial Transformed User Heading (fpHeading): 10.6°
flutter: └─────────────────────────────────────────────────
SWIFT TASK CONTINUATION MISUSE: setUpPlayerItemStatusObservation(_:) leaked its continuation without resuming it. This may cause tasks waiting on it to remain suspended forever.
flutter: ┌─────────────────────────────────────────────────
flutter: │ 11:22:45.045 (+0:13:37.648985)
flutter: ├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
flutter: │ 💡 📶 Tracking Confidence Transition:
flutter: │ 💡   - Previous Confidence: 0.50
flutter: │ 💡   - New Confidence: 1.00
flutter: │ 💡   - Current Raw Heading: 89.8°
flutter: └─────────────────────────────────────────────────

{
  "trajectory": [
    {
      "0": {
        "name": "destination",
        "building": "Langone",
        "floor": "17_floor",
        "paths": [
          [
            976.0663925204356,
            754.6575636986568,
            10.577674172398195
          ],
          [
            976.0663925204356,
            754.6575636986568
          ],
          [
            1212.4378109452734,
            785.5721393034825
          ],
          [
            1220.3980099502487,
            488.5572139303482
          ],
          [
            2393.3649289099526,
            532.7014218009479
          ]
        ],
        "command": {
          "instructions": [
            {
              "tag": "start_in",
              "text": "You are currently in corridor 6 on 17 floor of Langone, New York University.",
              "meta": {
                "room": "corridor 6",
                "floor": "17_floor",
                "building": "Langone",
                "place": "New_York_University"
              }
            },
            {
              "tag": "forward",
              "text": "Forward 5 meters",
              "meta": {
                "distance": 5.143621837861269,
                "unit": "meter",
                "edge_range": [
                  0,
                  0
                ],
                "node_range": [
                  0,
                  1
                ]
              }
            },
            {
              "tag": "turn",
              "text": "turn left to 9 o'clock",
              "meta": {
                "qual": "turn",
                "direction": "left",
                "hour": 9,
                "deg15": 105,
                "edge_index": 1,
                "node_index": 1
              }
            },
            {
              "tag": "forward_door",
              "text": "Forward 6 meters and go through a door in 3 meters",
              "meta": {
                "distance": 6.410992232863323,
                "unit": "meter",
                "door_distance": 3.4269883531427956,
                "door_unit": "meter",
                "edge_range": [
                  1,
                  1
                ],
                "node_range": [
                  1,
                  2
                ]
              }
            },
            {
              "tag": "turn",
              "text": "turn right to 3 o'clock",
              "meta": {
                "qual": "turn",
                "direction": "right",
                "hour": 3,
                "deg15": 90,
                "edge_index": 2,
                "node_index": 2
              }
            },
            {
              "tag": "forward_door",
              "text": "Forward 25 meters and go through a door in 3 meters",
              "meta": {
                "distance": 25.32702435402963,
                "unit": "meter",
                "door_distance": 3.3431552192489797,
                "door_unit": "meter",
                "edge_range": [
                  2,
                  2
                ],
                "node_range": [
                  2,
                  3
                ]
              }
            },
            {
              "tag": "arrive",
              "text": "1718 on 3 o'clock right",
              "meta": {
                "label": "1718",
                "hour": 3,
                "qual": "turn",
                "direction": "right",
                "node_index": 3,
                "edge_index": 2
              }
            }
          ],
          "are_instructions_generated": true
        },
        "scale": 0.02205862195
      }
    },
    null
  ],
  "scale": 0.02205862195
}



