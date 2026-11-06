# Warianty grafiki wg epok – tabela z danych EE/AoC (etap 8)

Wygenerowano: `narzedzia/warianty_epok.py` z `dbtechtree`, `dbevents`, `dbeffects` (kod 6 – zmiana grafiki),
`dbobjects` i `dbgraphics` instalacji AoC. Wiersz = epoka, od której obiekt ma daną grafikę (stan po nałożeniu
zmian wszystkich epok ≤ E). „Gniazda” = liczba wypełnionych ścieżek modelu w wierszu dbgraphics (sekwencje
animacji należą do grafiki – zmiana grafiki zmienia model, teksturę i animacje razem).

| Epoka | Nazwa epoki | Obiekt | Nazwa obiektu | Grafika | Nazwa grafiki | Model | Tekstura | Gniazda |
|---|---|---|---|---|---|---|---|---|
| 0 | (bazowa – dbobjects) | 1 | Priest | 246 | Priest01 | models/men_priest_02 | textures/men_priest_02T.sst | 1 |
| 4 | Epoch Bronze | 1 | Priest | 247 | Priest04 | models/men_priest_04 | textures/men_priest_04T.sst | 1 |
| 7 | Epoch Renaissance | 1 | Priest | 248 | Priest07 | models/men_priest_07 | textures/men_priest_07T.sst | 1 |
| 9 | Epoch Industrial | 1 | Priest | 149 | Priest09 | models/men_priest_07 | textures/men_priest_09T.sst | 1 |
| 13 | Epoch Digital | 1 | Priest | 367 | Priest11 | models/men_priest_11 | textures/men_priest_11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 32 | Citizen | 54 | Citizen Paleo | models/men_citizenone_01 | textures/men_citizen_01T.sst | 8 |
| 2 | Epoch Stone | 32 | Citizen | 55 | Citizen Stone | models/men_citizenone_02 | textures/men_citizen_02T.sst | 8 |
| 4 | Epoch Bronze | 32 | Citizen | 283 | Citizen Bronze | models/men_citizenone_04 | textures/men_citizen_04T.sst | 8 |
| 6 | Epoch Middle | 32 | Citizen | 282 | Citizen Middle | models/men_citizenone_06 | textures/men_citizen_06T.sst | 9 |
| 10 | Epoch Atomic - WW1 | 32 | Citizen | 56 | Citizen Atomic | models/men_citizenone_10 | textures/men_citizen_10T.sst | 8 |
| 14 | Epoch Nano | 32 | Citizen | 871 | Citizen - Nano | models/men_citizen_15 | textures/men_citizen_15T | 5 |
| 0 | (bazowa – dbobjects) | 34 | b  Barracks | 39 | Barracks - 01 | models/bld_barracks_01 | textures/bld_barracks_01T.sst | 1 |
| 3 | Epoch Copper | 34 | b  Barracks | 35 | Barracks - 03 | models/bld_barracks_03 | textures/bld_barracks_03T.sst | 1 |
| 4 | Epoch Bronze | 34 | b  Barracks | 36 | Barracks - 04 | models/bld_barracks_05 | textures/bld_barracks_05T.sst | 1 |
| 6 | Epoch Middle | 34 | b  Barracks | 727 | Barracks - 06 | models/bld_barracks_06 | textures/bld_barracks_06T.sst | 1 |
| 8 | Epoch Imperial | 34 | b  Barracks | 37 | Barracks - 08 | models/bld_barracks_08 | textures/bld_barracks_08T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 34 | b  Barracks | 34 | Barracks - 10 | models/bld_barracks_10 | textures/bld_barracks_10T.sst | 1 |
| 13 | Epoch Digital | 34 | b  Barracks | 38 | Barracks - 12 | models/bld_barracks_12 | textures/bld_barracks_12T.sst | 1 |
| 0 | (bazowa – dbobjects) | 35 | b  Town Center | 311 | Town Center - Paleo | models/bld_towncenter_01 | textures/bld_settlement_01T.sst | 1 |
| 2 | Epoch Stone | 35 | b  Town Center | 312 | Town Center - Stone | models/bld_towncenter_02 | textures/bld_towncenter_02T.sst | 1 |
| 3 | Epoch Copper | 35 | b  Town Center | 307 | Town Center - Copper | models/bld_towncenter_03 | textures/bld_towncenter_03T.sst | 1 |
| 4 | Epoch Bronze | 35 | b  Town Center | 306 | Town Center - Bronze | models/bld_towncenter_04 | textures/bld_towncenter_04T.sst | 1 |
| 6 | Epoch Middle | 35 | b  Town Center | 309 | Town Center - Middle | models/bld_towncenter_06 | textures/bld_towncenter_06T.sst | 1 |
| 8 | Epoch Imperial | 35 | b  Town Center | 308 | Town Center - Imperial | models/bld_towncenter_08 | textures/bld_towncenter_08T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 35 | b  Town Center | 305 | Town Center - Atomic | models/bld_towncenter_10 | textures/bld_towncenter_10T.sst | 1 |
| 13 | Epoch Digital | 35 | b  Town Center | 310 | Town Center - Nano | models/bld_towncenter_12 | textures/bld_towncenter_12T.sst | 1 |
| 0 | (bazowa – dbobjects) | 36 | b  Dock | 107 | Dock - Stone | models/bld_dock_02 | textures/bld_dock_02T.sst | 1 |
| 4 | Epoch Bronze | 36 | b  Dock | 104 | Dock - Bronze | models/bld_dock_04 | textures/bld_dock_04T.sst | 1 |
| 6 | Epoch Middle | 36 | b  Dock | 823 | Dock - Middle | models/bld_dock_08 | textures/bld_dock_06T.sst | 1 |
| 8 | Epoch Imperial | 36 | b  Dock | 105 | Dock - Imperial | models/bld_dock_08 | textures/bld_dock_08T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 36 | b  Dock | 103 | Dock - Atomic | models/bld_dock_10 | textures/bld_dock_10T.sst | 1 |
| 13 | Epoch Digital | 36 | b  Dock | 106 | Dock - Nano | models/bld_dock_14 | textures/bld_dock_14T.sst | 1 |
| 0 | (bazowa – dbobjects) | 37 | b  House | 174 | House - Paleo | models/bld_house_01 | textures/bld_house_01T.sst | 1 |
| 2 | Epoch Stone | 37 | b  House | 396 | House - Stone | models/bld_house_02 | textures/bld_house_02T.sst | 1 |
| 3 | Epoch Copper | 37 | b  House | 170 | House - Copper | models/bld_house_03 | textures/bld_house_03T.sst | 1 |
| 4 | Epoch Bronze | 37 | b  House | 51 | House - Bronze | models/bld_house_04 | textures/bld_house_04T.sst | 1 |
| 5 | Epoch Dark | 37 | b  House | 171 | House - Dark | models/bld_house_05 | textures/bld_house_05T.sst | 1 |
| 6 | Epoch Middle | 37 | b  House | 90 | House - Middle | models/bld_house_06 | textures/bld_house_06T.sst | 1 |
| 7 | Epoch Renaissance | 37 | b  House | 175 | House -Renai. | models/bld_house_07 | textures/bld_house_07T.sst | 1 |
| 8 | Epoch Imperial | 37 | b  House | 418 | House - Imperial | models/bld_house_08 | textures/bld_house_08T.sst | 1 |
| 9 | Epoch Industrial | 37 | b  House | 172 | House - Industrial | models/bld_house_09 | textures/bld_house_09T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 37 | b  House | 397 | House - Atomic | models/bld_house_10 | textures/bld_house_10T.sst | 1 |
| 13 | Epoch Digital | 37 | b  House | 173 | House - Info | models/bld_house_11 | textures/bld_house_11T.sst | 1 |
| 14 | Epoch Nano | 37 | b  House | 417 | House - Nano | models/bld_house_12 | textures/bld_house_12T.sst | 1 |
| 15 | Epoch Space | 37 | b  House | 858 | House - Space | models/bld_house_15 | textures/bld_house_15t | 1 |
| 0 | (bazowa – dbobjects) | 39 | b  Temple | 302 | Temple - Stone | models/bld_temple_02 | textures/bld_temple_02T.sst | 1 |
| 4 | Epoch Bronze | 39 | b  Temple | 297 | Temple - Bronze | models/bld_temple_04 | textures/bld_temple_04T.sst | 1 |
| 6 | Epoch Middle | 39 | b  Temple | 301 | Temple - Middle. | models/bld_temple_06 | textures/bld_temple_06T.sst | 1 |
| 9 | Epoch Industrial | 39 | b  Temple | 299 | Temple - Industrial | models/bld_temple_09 | textures/bld_temple_09T.sst | 1 |
| 13 | Epoch Digital | 39 | b  Temple | 300 | Temple - Nano | models/bld_temple_14 | textures/bld_temple_14T.sst | 1 |
| 0 | (bazowa – dbobjects) | 41 | b  Capitol | 144 | Gov Center - Stone | models/bld_capital_02 | textures/bld_towncenter_02T.sst | 1 |
| 3 | Epoch Copper | 41 | b  Capitol | 350 | Gov Center - Copper | models/bld_capital_03 | textures/bld_towncenter_03T.sst | 1 |
| 4 | Epoch Bronze | 41 | b  Capitol | 140 | Gov Center - Bronze | models/bld_capital_04 | textures/bld_towncenter_04T.sst | 1 |
| 6 | Epoch Middle | 41 | b  Capitol | 142 | Gov Center - Middle | models/bld_capital_06 | textures/bld_towncenter_06T.sst | 1 |
| 8 | Epoch Imperial | 41 | b  Capitol | 141 | Gov Center - Imperial | models/bld_capital_08 | textures/bld_towncenter_08T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 41 | b  Capitol | 139 | Gov Center - Atomic | models/bld_capital_10 | textures/bld_towncenter_10T.sst | 1 |
| 13 | Epoch Digital | 41 | b  Capitol | 143 | Gov Center - Digital | models/bld_capital_12 | textures/bld_towncenter_12T.sst | 1 |
| 15 | Epoch Space | 41 | b  Capitol | 892 | Gov Center - Space | models/bld_capitol_15 | textures/bld_capitol_15t | 1 |
| 0 | (bazowa – dbobjects) | 42 | b  Farm | 592 | Programmer  Farm | models/fx_dummy_farm |  | 1 |
| 0 | (bazowa – dbobjects) | 43 | b  Settlement | 145 | Settlement - Paleo | models/bld_settlement_01 | textures/bld_settlement_01T.sst | 1 |
| 3 | Epoch Copper | 43 | b  Settlement | 800 | Settlement - Copper | models/bld_settlement_03 | textures/bld_towncenter_03T.sst | 1 |
| 4 | Epoch Bronze | 43 | b  Settlement | 726 | Settlement - Bronze | models/bld_settlement_04 | textures/bld_towncenter_04T.sst | 1 |
| 6 | Epoch Middle | 43 | b  Settlement | 146 | Settlement - Middle | models/bld_settlement_06 | textures/bld_towncenter_06T.sst | 1 |
| 8 | Epoch Imperial | 43 | b  Settlement | 147 | Settlement - Imperial | models/bld_settlement_08 | textures/bld_towncenter_08T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 43 | b  Settlement | 675 | Settlement - Atomic | models/bld_settlement_10 | textures/bld_settlement_10T.sst | 1 |
| 13 | Epoch Digital | 43 | b  Settlement | 695 | Settlement - Digital | models/bld_settlement_12 | textures/bld_towncenter_12T.sst | 1 |
| 0 | (bazowa – dbobjects) | 52 | b  Granary | 492 | Granary/Mill - Copper | models/bld_granary_03 | textures/bld_granary_03T.sst | 1 |
| 4 | Epoch Bronze | 52 | b  Granary | 620 | Granary/Mill - Bronze | models/bld_granary_04 | textures/bld_granary_04T.sst | 1 |
| 6 | Epoch Middle | 52 | b  Granary | 493 | Granary/Mill - Middle | models/bld_granary_06 | textures/bld_granary_06T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 52 | b  Granary | 628 | Granary/Mill - Imperial | models/bld_granary_08 | textures/bld_granary_08T.sst | 1 |
| 13 | Epoch Digital | 52 | b  Granary | 491 | Granary/Mill - Info | models/bld_granary_11 | textures/bld_granary_11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 54 | b  Archery Range | 17 | Archery Range - 03 | models/bld_archery_03 | textures/bld_archery_03T.sst | 1 |
| 4 | Epoch Bronze | 54 | b  Archery Range | 18 | Archery Range - 05 | models/bld_archery_05 | textures/bld_archery_05T.sst | 1 |
| 6 | Epoch Middle | 54 | b  Archery Range | 16 | Archery Range - 07 | models/bld_archery_07 | textures/bld_archery_07T.sst | 1 |
| 0 | (bazowa – dbobjects) | 56 | Scaffolding 1x1 | 500 | Dummy | models/fx_dummy_00 |  | 1 |
| 3 | Epoch Copper | 56 | Scaffolding 1x1 | 810 | Scaffolding Copper 1x1 | models/bld_scaffolding03_A | textures/bld_scaffolding03T.sst | 1 |
| 9 | Epoch Industrial | 56 | Scaffolding 1x1 | 808 | Scaffolding Industrial 1x1 | models/bld_scaffolding09_A | textures/bld_scaffolding09T.sst | 1 |
| 13 | Epoch Digital | 56 | Scaffolding 1x1 | 809 | Scaffolding Atomic 1x1 | models/bld_scaffolding11_A | textures/bld_scaffolding11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 60 | b  University | 790 | University - Copper | models/bld_university_03 | textures/bld_university_03T.sst | 1 |
| 4 | Epoch Bronze | 60 | b  University | 327 | University - Bronze | models/bld_university_04 | textures/bld_university_04T.sst | 1 |
| 6 | Epoch Middle | 60 | b  University | 329 | University - Middle | models/bld_university_06 | textures/bld_university_06T.sst | 1 |
| 8 | Epoch Imperial | 60 | b  University | 328 | University - Industrial | models/bld_university_08 | textures/bld_university_08T.sst | 1 |
| 13 | Epoch Digital | 60 | b  University | 330 | University - Info | models/bld_university_11 | textures/bld_university_11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 62 | b  Hospital | 166 | Hospital - Copper | models/bld_hospital_03 | textures/bld_hospital_03T.sst | 1 |
| 4 | Epoch Bronze | 62 | b  Hospital | 165 | Hospital - Bronze | models/bld_hospital_04 | textures/bld_hospital_04T.sst | 1 |
| 6 | Epoch Middle | 62 | b  Hospital | 169 | Hospital - Middle | models/bld_hospital_06 | textures/bld_hospital_06T.sst | 1 |
| 8 | Epoch Imperial | 62 | b  Hospital | 167 | Hospital - Industrial | models/bld_hospital_09 | textures/bld_hospital_09T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 62 | b  Hospital | 735 | Hospital - Atomic | models/bld_hospital_10 | textures/bld_hospital_10T.sst | 1 |
| 13 | Epoch Digital | 62 | b  Hospital | 168 | Hospital - Info | models/bld_hospital_11 | textures/bld_hospital_11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 63 | b  Siege Factory | 272 | SiegeWorkshop - Bronze | models/bld_siege_04 | textures/bld_siege_04T.sst | 1 |
| 6 | Epoch Middle | 63 | b  Siege Factory | 269 | Siege Workshop- Middle | models/bld_siege_06 | textures/bld_siege_04T.sst | 1 |
| 7 | Epoch Renaissance | 63 | b  Siege Factory | 271 | Siege Workshop- Renaissance | models/bld_siege_07 | textures/bld_siege_07T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 63 | b  Siege Factory | 268 | Siege Workshop - Atomic | models/bld_siege_10 | textures/bld_siege_10T.sst | 1 |
| 13 | Epoch Digital | 63 | b  Siege Factory | 426 | Siege Workshop- Info | models/bld_siege_11 | textures/bld_siege_11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 64 | b  Stable | 280 | Stable - Copper | models/bld_stable_03 | textures/bld_stable_03T.sst | 1 |
| 4 | Epoch Bronze | 64 | b  Stable | 512 | Stable - Bronze | models/bld_stable_05 | textures/bld_stable_05T.sst | 1 |
| 6 | Epoch Middle | 64 | b  Stable | 281 | Stable - Middle | models/bld_stable_07 | textures/bld_stable_07T.sst | 1 |
| 0 | (bazowa – dbobjects) | 65 | b  Navy Yard | 234 | Naval Yard - Atomic | models/bld_naval_10 | textures/bld_naval_10T.sst | 1 |
| 13 | Epoch Digital | 65 | b  Navy Yard | 721 | Naval Yard - Nano | models/bld_naval_14 | textures/bld_navalyard_14T.sst | 1 |
| 0 | (bazowa – dbobjects) | 66 | b  Airport | 10 | Airfield - Atomic | models/bld_airfield_10 | textures/bld_airfield_10T.sst | 1 |
| 13 | Epoch Digital | 66 | b  Airport | 11 | Airfield - Digital | models/bld_airfield_12 | textures/bld_airfield_12T.sst | 1 |
| 0 | (bazowa – dbobjects) | 67 | x Missile Base | 229 | Missile Base - Atomic | models/bld_missilebase_10 | textures/bld_missilebase_10T.sst | 1 |
| 14 | Epoch Nano | 67 | x Missile Base | 230 | Missile Base - Nano | models/bld_missilebase_12 | textures/bld_missilebase_12T.sst | 1 |
| 0 | (bazowa – dbobjects) | 68 | b  Tank Factory | 293 | Tank Factory - Atomic | models/bld_tankfactory_10 | textures/bld_tankfactory_10T.sst | 1 |
| 13 | Epoch Digital | 68 | b  Tank Factory | 294 | Tank Factory - Info | models/bld_tankfactory_12 | textures/bld_tankfactory_12T.sst | 1 |
| 0 | (bazowa – dbobjects) | 172 | x Diplomat | 540 | x Wealthy Citizen - Stone | models/men_citizenone_02 | textures/men_wealthycitizen_02T.sst | 8 |
| 4 | Epoch Bronze | 172 | x Diplomat | 541 | x Wealthy Citizen - Bronze | models/men_citizenone_04 | textures/men_wealthycitizen_04T.sst | 8 |
| 6 | Epoch Middle | 172 | x Diplomat | 542 | x Wealthy Citizen - Middle | models/men_wealthycitizen_06 | textures/men_wealthycitizen_06T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 172 | x Diplomat | 543 | x Wealthy Citizen - Atomic | models/men_citizenone_10 | textures/men_wealthycitizen_10T.sst | 8 |
| 0 | (bazowa – dbobjects) | 184 | Scaffolding 2x2 | 500 | Dummy | models/fx_dummy_00 |  | 1 |
| 3 | Epoch Copper | 184 | Scaffolding 2x2 | 15 | Scaffolding Copper 2x2 | models/bld_scaffolding03_B | textures/bld_scaffolding03T.sst | 1 |
| 9 | Epoch Industrial | 184 | Scaffolding 2x2 | 468 | Scaffolding Industrial 2x2 | models/bld_scaffolding09_B | textures/bld_scaffolding09T.sst | 1 |
| 13 | Epoch Digital | 184 | Scaffolding 2x2 | 253 | Scaffolding Atomic 2x2 | models/bld_scaffolding11_B | textures/bld_scaffolding11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 200 | Scaffolding 3x3 | 500 | Dummy | models/fx_dummy_00 |  | 1 |
| 3 | Epoch Copper | 200 | Scaffolding 3x3 | 182 | Scaffolding Copper 3x3 | models/bld_scaffolding03_C | textures/bld_scaffolding03T.sst | 1 |
| 9 | Epoch Industrial | 200 | Scaffolding 3x3 | 189 | Scaffolding Industrial 3x3 | models/bld_scaffolding09_C | textures/bld_scaffolding09T.sst | 1 |
| 13 | Epoch Digital | 200 | Scaffolding 3x3 | 252 | Scaffolding Atomic 3x3 | models/bld_scaffolding11_C | textures/bld_scaffolding11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 216 | Prophet | 250 | Prophet - Stone | models/men_prophet_02 | textures/men_prophet_02T.sst | 1 |
| 4 | Epoch Bronze | 216 | Prophet | 535 | Prophet - Bronze | models/men_homer_04 | textures/men_homer_04T.sst | 1 |
| 7 | Epoch Renaissance | 216 | Prophet | 251 | Prophet - Ren | models/men_prophet_07 | textures/men_prophet_07T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 216 | Prophet | 744 | Prophet - Atomic | models/men_prophet_10 | textures/men_prophet_10T.sst | 1 |
| 0 | (bazowa – dbobjects) | 222 | x Child Citizen | 120 | x Child Citizen - Stone | models/men_childcitizen_02 | textures/men_childcitizen_02T.sst | 1 |
| 4 | Epoch Bronze | 222 | x Child Citizen | 119 | x Child Citizen - Bronze | models/men_childcitizen_04 | textures/men_childcitizen_04T.sst | 1 |
| 6 | Epoch Middle | 222 | x Child Citizen | 117 | x Child Citizen - Middle | models/men_childcitizen_02 | textures/men_childcitizen_06T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 222 | x Child Citizen | 116 | x Child Citizen - Atomic | models/men_childcitizen_02 | textures/men_childcitizen_10T.sst | 1 |
| 0 | (bazowa – dbobjects) | 225 | ICBM | 225 | Nuclear Missile | models/gun_nuke_10 | textures/gun_nuke_10T.sst | 1 |
| 14 | Epoch Nano | 225 | ICBM | 508 | Missile for Nano Missile Base | models/fx_missile_00 | textures/fx_missile_00T.sst | 1 |
| 0 | (bazowa – dbobjects) | 240 | b  Airport Runway | 364 | Airfield (runway) | models/fx_runway_00 |  | 1 |
| 13 | Epoch Digital | 240 | b  Airport Runway | 344 | Airfield  nano (runway) | models/fx_runway_00 |  | 1 |
| 0 | (bazowa – dbobjects) | 480 | Female Citizen | 718 | Female Citizen - Paleo | models/men_femcitizenone_01 | textures/men_femcitizen_01T.sst | 7 |
| 2 | Epoch Stone | 480 | Female Citizen | 595 | Female Citizen - Stone | models/men_femcitizenone_02 | textures/men_femcitizen_02T.sst | 8 |
| 4 | Epoch Bronze | 480 | Female Citizen | 596 | Female Citizen - Bronze | models/men_femcitizenone_04 | textures/men_femcitizen_04T.sst | 8 |
| 6 | Epoch Middle | 480 | Female Citizen | 591 | Female Citizen - Middle | models/men_femcitizenone_06 | textures/men_femcitizen_06T.sst | 8 |
| 10 | Epoch Atomic - WW1 | 480 | Female Citizen | 593 | Female Citizen - Atomic | models/men_femcitizenone_10 | textures/men_femcitizen_10T.sst | 8 |
| 14 | Epoch Nano | 480 | Female Citizen | 872 | Female Citizen - Nano | models/men_citizen_15 | textures/men_citizen_15T | 5 |
| 0 | (bazowa – dbobjects) | 656 | Citizen Projectile | 435 | Spear1 | models/citizenspear_00 | textures/fx_spear_00T.sst | 1 |
| 6 | Epoch Middle | 656 | Citizen Projectile | 370 | Arrow | models/FX_Arrow | textures/fx_arrowT.sst | 1 |
| 10 | Epoch Atomic - WW1 | 656 | Citizen Projectile | 500 | Dummy | models/fx_dummy_00 |  | 1 |
| 0 | (bazowa – dbobjects) | 672 | b  Fortress | 742 | Fortress - Copper | models/bld_fortress_03 | textures/bld_fortress_03T.sst | 1 |
| 4 | Epoch Bronze | 672 | b  Fortress | 746 | Fortress - Bronze | models/bld_fortress_04 | textures/bld_fortress_04T.sst | 1 |
| 6 | Epoch Middle | 672 | b  Fortress | 748 | Fortress - Middle | models/bld_fortress_06 | textures/bld_fortress_06T.sst | 1 |
| 8 | Epoch Imperial | 672 | b  Fortress | 763 | Fortress - Imperial | models/bld_fortress_08 | textures/bld_fortress_08T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 672 | b  Fortress | 745 | Fortress - Atomic | models/bld_fortress_10 | textures/bld_fortress_10T.sst | 1 |
| 13 | Epoch Digital | 672 | b  Fortress | 747 | Fortress - Nano | models/bld_fortress_12 | textures/bld_fortress_12T.sst | 1 |
| 0 | (bazowa – dbobjects) | 698 | b  Granary Improved | 492 | Granary/Mill - Copper | models/bld_granary_03 | textures/bld_granary_03T.sst | 1 |
| 4 | Epoch Bronze | 698 | b  Granary Improved | 620 | Granary/Mill - Bronze | models/bld_granary_04 | textures/bld_granary_04T.sst | 1 |
| 6 | Epoch Middle | 698 | b  Granary Improved | 493 | Granary/Mill - Middle | models/bld_granary_06 | textures/bld_granary_06T.sst | 1 |
| 10 | Epoch Atomic - WW1 | 698 | b  Granary Improved | 628 | Granary/Mill - Imperial | models/bld_granary_08 | textures/bld_granary_08T.sst | 1 |
| 13 | Epoch Digital | 698 | b  Granary Improved | 491 | Granary/Mill - Info | models/bld_granary_11 | textures/bld_granary_11T.sst | 1 |
| 0 | (bazowa – dbobjects) | 718 | Wealthy Citizen Projectile | 435 | Spear1 | models/citizenspear_00 | textures/fx_spear_00T.sst | 1 |
| 6 | Epoch Middle | 718 | Wealthy Citizen Projectile | 500 | Dummy | models/fx_dummy_00 |  | 1 |
| 0 | (bazowa – dbobjects) | 724 | Emissary | 246 | Priest01 | models/men_priest_02 | textures/men_priest_02T.sst | 1 |
| 4 | Epoch Bronze | 724 | Emissary | 247 | Priest04 | models/men_priest_04 | textures/men_priest_04T.sst | 1 |
| 7 | Epoch Renaissance | 724 | Emissary | 248 | Priest07 | models/men_priest_07 | textures/men_priest_07T.sst | 1 |
| 9 | Epoch Industrial | 724 | Emissary | 149 | Priest09 | models/men_priest_07 | textures/men_priest_09T.sst | 1 |
| 13 | Epoch Digital | 724 | Emissary | 367 | Priest11 | models/men_priest_11 | textures/men_priest_11T.sst | 1 |

## Epoki (dbtechtree → dbevents)

| Tech ID | Epoka | Numer | Event ID | Zmian grafiki |
|---|---|---|---|---|
| 0 | Epoch Paleo | 1 | 62 | 0 |
| 1 | Epoch Stone | 2 | 68 | 5 |
| 2 | Epoch Copper | 3 | 66 | 11 |
| 3 | Epoch Bronze | 4 | 60 | 22 |
| 4 | Epoch Dark | 5 | 59 | 1 |
| 5 | Epoch Middle | 6 | 64 | 21 |
| 6 | Epoch Renaissance | 7 | 63 | 5 |
| 7 | Epoch Imperial | 8 | 61 | 9 |
| 8 | Epoch Industrial | 9 | 57 | 7 |
| 9 | Epoch Atomic - WW1 | 10 | 65 | 17 |
| 10 | Epoch Atomic - WW2 | 11 | 431 | 0 |
| 11 | Epoch Atomic - Modern | 12 | 432 | 0 |
| 12 | Epoch Digital | 13 | 58 | 22 |
| 13 | Epoch Nano | 14 | 67 | 5 |
| 14 | Epoch Space | 15 | 628 | 2 |
