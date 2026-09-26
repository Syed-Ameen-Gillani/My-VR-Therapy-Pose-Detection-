# Pose summary scoring

`pose_match_percent` and `pose_rating` are derived from ML Kit landmarks by
exercise rules, not direct model outputs or clinically validated accuracy.
The UI uses “Pose match” and “Pose rating”. Existing timer and repetition rules
are unchanged.

Scoring uses the existing five-reading smoothed metric. Full match is awarded
inside the exercise target: shoulder reach >=70°, knee extension / sit to stand
>=155°, arm hold >=60°, shoulder abduction >=75°, elbow flexion <=70°,
hip flexion <=80°, knee flexion <=90°, seated balance offset <=0.15,
and trunk alignment offset <=0.25. Offset metrics are normalized ratios.

Outside the target, match decreases linearly to zero over 45° of angular error,
0.30 additional balance offset, or 0.50 additional trunk offset. Where the
existing analyzer measures trunk lean, lean above 0.30 decreases trunk match
linearly to zero at 0.80. The lower of movement match and trunk match is used.
These are prototype scoring choices, not learned or clinically calibrated values.

The result is a time-weighted mean using adjacent valid observations. Tracking
loss, pauses and gaps over 500 ms break score continuity; unseen time contributes
nothing. At least two measured seconds and 50% accepted frames are required.
Acquisition movements while recording are included. Scoring stops at completion.
This measures observed target agreement, not quality of an entire movement cycle.

Ratings: Outstanding 95-100%, Excellent 85-94%, Good 75-84%, Average 60-74%,
Fair 45-59%, Poor 30-44% and Very Poor 0-29%. Insufficient evidence or older
records without a score display "Not available", never an invented zero.

Scores, ratings, evidence duration and `pose_score_version: target-match-v1` are
saved in the existing `analysis_payload` JSON. No database migration is needed.
