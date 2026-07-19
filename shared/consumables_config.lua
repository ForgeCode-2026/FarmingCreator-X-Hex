Config.Consumables = {
    Inventory = 'framework',
    Progress = 'fc_hud',
    RemoveItem = true,
    AllowCancel = true,
    CancelKey = 73,
    CompletionToleranceMs = 250,
    DefaultCooldownMs = 1500,
    CreatorCommand = 'consumablescreator',
    RequestTimeoutMs = 5000,
}

Config.AnimationPresets = {
    rauchen = {
        scenario = 'WORLD_HUMAN_SMOKING'
    },

    joint = {
        dict = 'amb@world_human_aa_smoke@male@idle_a',
        clip = 'idle_c',
        flag = 49,
        prop = {
            model = 'p_cs_joint_02',
            bone = 28422,
            position = vector3(0.0, 0.0, 0.0),
            rotation = vector3(0.0, 0.0, 0.0)
        }
    },

    pille = {
        dict = 'mp_suicide',
        clip = 'pill',
        flag = 49,
        prop = {
            model = 'prop_cs_pills',
            bone = 28422,
            position = vector3(0.0, 0.0, 0.0),
            rotation = vector3(0.0, 0.0, 0.0)
        }
    },

    kokain = {
        dict = 'anim@amb@nightclub@peds@',
        clip = 'missfbi3_party_snort_coke_b_male3',
        flag = 49
    },

    meth = {
        dict = 'switch@trevor@trev_smoking_meth',
        clip = 'trev_smoking_meth_loop',
        flag = 49,
        prop = {
            model = 'prop_cs_crackpipe',
            bone = 28422,
            position = vector3(0.0, 0.0, 0.0),
            rotation = vector3(0.0, 0.0, 0.0)
        }
    },

    trinken = {
        dict = 'mp_player_intdrink',
        clip = 'loop_bottle',
        flag = 49,
        prop = {
            model = 'prop_ld_flow_bottle',
            bone = 18905,
            position = vector3(0.12, 0.03, 0.02),
            rotation = vector3(-90.0, 0.0, 0.0)
        }
    },

    essen = {
        dict = 'mp_player_inteat@burger',
        clip = 'mp_player_int_eat_burger',
        flag = 49,
        prop = {
            model = 'prop_cs_burger_01',
            bone = 18905,
            position = vector3(0.13, 0.05, 0.02),
            rotation = vector3(-50.0, 16.0, 60.0)
        }
    },

    ruestung = {
        dict = 'clothingtie',
        clip = 'try_tie_positive_a',
        flag = 48
    }
}

Config.HallucinationPresets = {
    leicht = {
        label = 'Leichter Rausch',
        timecycle = 'spectator5',
        strength = 0.3,
        cameraShake = 0.1,
        motionBlur = true
    },

    mittel = {
        label = 'Mittlerer Rausch',
        timecycle = 'spectator5',
        strength = 0.55,
        pulsing = true,
        cameraShake = 0.2,
        motionBlur = true
    },

    stark = {
        label = 'Starker Rausch',
        timecycle = 'drug_drive_blend01',
        strength = 0.75,
        pulsing = true,
        screenEffect = 'DrugsMichaelAliensFight',
        cameraShake = 0.45,
        motionBlur = true,
        movementClipset = 'move_m@drunk@moderatedrunk',
        ragdollChance = 4
    },

    trip = {
        label = 'Voller Trip',
        timecycle = 'spectator5',
        strength = 1.0,
        pulsing = true,
        screenEffect = 'DrugsMichaelAliensFight',
        cameraShake = 0.65,
        motionBlur = true,
        movementClipset = 'move_m@drunk@verydrunk',
        ragdollChance = 7
    }
}

Config.Items = {
    cigarette = {
        label = 'Zigarette',
        cooldown = 1500,
        consume = {
            duration = 6000,
            text = 'Du rauchst eine Zigarette ...',
            allowInVehicle = false,
            animation = 'rauchen'
        },
        effects = {
            duration = 0
        }
    },

    joint = {
        label = 'Joint',
        cooldown = 2500,
        consume = {
            duration = 7000,
            text = 'Du rauchst einen Joint ...',
            allowInVehicle = false,
            animation = 'joint'
        },
        effects = {
            duration = 90000,
            health = 5,
            hallucination = {
                timecycle = 'spectator5',
                strength = 0.35,
                pulsing = true,
                screenEffect = 'DrugsTrevorClownsFight',
                cameraShake = 0.18,
                motionBlur = true,
                movementClipset = 'move_m@drunk@slightlydrunk'
            }
        }
    },

    painkiller = {
        label = 'Schmerztablette',
        cooldown = 2500,
        consume = {
            duration = 3500,
            text = 'Du nimmst eine Tablette ...',
            allowInVehicle = true,
            animation = 'pille'
        },
        effects = {
            duration = 0,
            health = 25
        }
    },

    adrenaline = {
        label = 'Adrenalin',
        cooldown = 5000,
        consume = {
            duration = 4500,
            text = 'Du verwendest Adrenalin ...',
            allowInVehicle = false,
            animation = 'pille'
        },
        effects = {
            duration = 45000,
            armor = 20,
            speed = 1.20,
            stamina = true,
            hallucination = {
                timecycle = 'RaceTurbo',
                strength = 0.25,
                pulsing = false,
                cameraShake = 0.08,
                motionBlur = true
            }
        }
    },

    cocaine = {
        label = 'Kokain',
        cooldown = 5000,
        consume = {
            duration = 5500,
            text = 'Du konsumierst Kokain ...',
            allowInVehicle = false,
            animation = 'kokain'
        },
        effects = {
            duration = 75000,
            speed = 1.28,
            stamina = true,
            hallucination = {
                timecycle = 'spectator5',
                strength = 0.55,
                pulsing = true,
                screenEffect = 'DrugsMichaelAliensFight',
                cameraShake = 0.32,
                motionBlur = true
            }
        }
    },

    meth = {
        label = 'Meth',
        cooldown = 5000,
        consume = {
            duration = 7000,
            text = 'Du rauchst Meth ...',
            allowInVehicle = false,
            animation = 'meth'
        },
        effects = {
            duration = 100000,
            armor = 25,
            speed = 1.38,
            stamina = true,
            hallucination = {
                timecycle = 'drug_drive_blend01',
                strength = 0.75,
                pulsing = true,
                screenEffect = 'DrugsTrevorClownsFight',
                cameraShake = 0.48,
                motionBlur = true,
                movementClipset = 'move_m@drunk@moderatedrunk',
                ragdollChance = 4
            }
        }
    },

    lsd = {
        label = 'LSD',
        cooldown = 5000,
        consume = {
            duration = 3500,
            text = 'Du nimmst LSD ...',
            allowInVehicle = true,
            animation = 'pille'
        },
        effects = {
            duration = 120000,
            hallucination = {
                timecycle = 'spectator5',
                strength = 1.0,
                pulsing = true,
                screenEffect = 'DrugsMichaelAliensFight',
                cameraShake = 0.65,
                motionBlur = true,
                movementClipset = 'move_m@drunk@verydrunk',
                ragdollChance = 7
            }
        }
    }
}
