# GoodWatch 1000-Persona QA Report
Generated: 2026-03-14
Duration: 518.8s

## OVERALL VERDICT: NO-GO

## Summary
- Total personas tested: 1000
- Overall pass rate: 96.2%
- Critical failures: 172
- Warnings: 210

## Invariant Results
| Invariant | Pass Rate | Failures | Severity |
|-----------|-----------|----------|----------|
| Non-repetition | 100.0% | 0 | CRITICAL |
| Mood accuracy | 80.9% | 191 | WARN |
| Platform availability | 100.0% | 0 | CRITICAL |
| Quality floor (>= 6.0) | 82.8% | 172 | CRITICAL |
| Genre diversity (<= 3/genre) | 98.1% | 19 | WARN |
| Language match | 100.0% | 0 | CRITICAL |
| Cold start (>= 5 recs) | 100.0% | 0 | CRITICAL |
| Veteran user (>= 5 recs) | 100.0% | 0 | WARN |
| Response determinism | 100.0% | 0 | WARN |
| No null results (>= 5) | 100.0% | 0 | CRITICAL |

## Critical Failures (blockers for launch)

### Quality floor (>= 6.0) (172 failures)
- **persona_0004** [mood=dark_heavy, lang=telugu, platform=sony_liv]: "Check" score 5.6 < 6.0
- **persona_0011** [mood=easy_watch, lang=telugu, platform=sony_liv]: "Check" score 5.6 < 6.0
- **persona_0018** [mood=gripping, lang=telugu, platform=sony_liv]: "Check" score 5.6 < 6.0
- **persona_0019** [mood=dark_heavy, lang=malayalam, platform=zee5]: "Karthika Deepam" score 0.0 < 6.0
- **persona_0025** [mood=feel_good, lang=telugu, platform=sony_liv]: "Ramarao On Duty" score 5.2 < 6.0
- ... and 167 more

## Top 10 Worst Performing Moods
| Rank | Mood | Failure Rate | Failures / Total |
|------|------|-------------|------------------|
| 1 | easy_watch | 55.0% | 110/200 |
| 2 | feel_good | 51.0% | 102/200 |
| 3 | dark_heavy | 35.5% | 71/200 |
| 4 | gripping | 14.5% | 29/200 |
| 5 | surprise_me | 14.0% | 28/200 |

## Top 10 Worst Performing Platforms
| Rank | Platform | Failure Rate | Failures / Total |
|------|----------|-------------|------------------|
| 1 | sony_liv | 100.0% | 143/143 |
| 2 | zee5 | 48.3% | 69/143 |
| 3 | netflix | 41.3% | 59/143 |
| 4 | apple_tv | 38.5% | 55/143 |
| 5 | jio_hotstar | 7.7% | 11/143 |
| 6 | jio_hotstar+netflix+prime | 1.4% | 2/142 |
| 7 | prime | 0.7% | 1/143 |

## Sample Failures (up to 5 examples per invariant)

### Mood accuracy
- **persona_0000** [mood=feel_good, lang=[hindi], platform=[netflix], seen=0, series=false, style=safe]
  4/10 recs have no mood match (mood: feel_good)
- **persona_0005** [mood=feel_good, lang=[malayalam], platform=[zee5], seen=0, series=false, style=adventurous]
  4/10 recs have no mood match (mood: feel_good)
- **persona_0010** [mood=feel_good, lang=[tamil], platform=[apple_tv], seen=0, series=false, style=balanced]
  4/10 recs have no mood match (mood: feel_good)
- **persona_0011** [mood=easy_watch, lang=[telugu], platform=[sony_liv], seen=0, series=false, style=adventurous]
  5/10 recs have no mood match (mood: easy_watch)
- **persona_0021** [mood=easy_watch, lang=[hindi], platform=[netflix], seen=0, series=false, style=safe]
  4/10 recs have no mood match (mood: easy_watch)

### Quality floor (>= 6.0)
- **persona_0004** [mood=dark_heavy, lang=[telugu], platform=[sony_liv], seen=0, series=false, style=balanced]
  "Check" score 5.6 < 6.0
- **persona_0011** [mood=easy_watch, lang=[telugu], platform=[sony_liv], seen=0, series=false, style=adventurous]
  "Check" score 5.6 < 6.0
- **persona_0018** [mood=gripping, lang=[telugu], platform=[sony_liv], seen=0, series=false, style=safe]
  "Check" score 5.6 < 6.0
- **persona_0019** [mood=dark_heavy, lang=[malayalam], platform=[zee5], seen=0, series=true, style=balanced]
  "Karthika Deepam" score 0.0 < 6.0
- **persona_0025** [mood=feel_good, lang=[telugu], platform=[sony_liv], seen=0, series=false, style=balanced]
  "Ramarao On Duty" score 5.2 < 6.0

### Genre diversity (<= 3/genre)
- **persona_0079** [mood=dark_heavy, lang=[hindi,english], platform=[jio_hotstar], seen=0, series=true, style=balanced]
  Primary genre "sci-fi & fantasy" appears 4 times in 10 recs
- **persona_0139** [mood=dark_heavy, lang=[hindi,english,tamil], platform=[jio_hotstar,netflix,prime], seen=0, series=true, style=balanced]
  Primary genre "drama" appears 4 times in 10 recs
- **persona_0149** [mood=dark_heavy, lang=[hindi,english], platform=[jio_hotstar], seen=0, series=true, style=adventurous]
  Primary genre "sci-fi & fantasy" appears 4 times in 10 recs
- **persona_0209** [mood=dark_heavy, lang=[hindi,english,tamil], platform=[jio_hotstar,netflix,prime], seen=0, series=true, style=adventurous]
  Primary genre "crime" appears 4 times in 10 recs
- **persona_0266** [mood=easy_watch, lang=[hindi], platform=[netflix], seen=5, series=false, style=adventurous]
  Primary genre "comedy" appears 4 times in 10 recs

## Recommendations
1. Add genre diversity penalty to scoring to prevent >3 same-genre picks in top 10
2. Review mood mapping for "easy_watch" - highest mismatch rate at 55.0%
3. Tighten adaptive quality gate floor - some movies below 6.0 rating are slipping through

## GO / NO-GO Verdict
**NO-GO** - The following CRITICAL invariants are below 90%:
- Quality floor (>= 6.0): 82.8%
