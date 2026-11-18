import Foundation

// Voice: singing lessons that listen through the microphone.
// Exercises are written as scale degrees and are moved into the singer's own range by the app.

extension Curriculum {
    static var voice: CurriculumSection {
        CurriculumSection(id: "voice", title: "Voice", symbol: "music.mic",
                          units: [vStart, vBreath, vMatch, vScales, vIntervals, vWarmups, vSongs])
    }

    // MARK: - Unit 1: Getting started

    static var vStart: CurriculumUnit {
        unit("voice.start", "Getting started", [
            lesson("voice.start.welcome", "How singing lessons work", "The microphone, headphones and looking after your voice.", [
                L.info("The app listens to you",
                       "In this section the app listens through the **microphone** and works out the **pitch** of your voice many times a second.\n\n- Your voice is drawn as a **line** that moves up when you sing higher and down when you sing lower\n- The notes to sing appear as **bars**. When your line sits on a bar, you are in tune and the line turns green\n- The note you are singing also **lights up on the keyboard** at the bottom of the window\n\nEvery exercise is moved into **your own range** automatically, and the right note counts in any octave, so nobody has to sing uncomfortably high or low."),
                L.info("Microphone and headphones",
                       "The first time you open a singing step, macOS asks whether Piano Coach may use the microphone. Choose **Allow**.\n\n**Without headphones** the app plays your starting note and a count-in, then stays silent while you sing. Otherwise the microphone would hear the piano instead of you.\n\n**With headphones** turn on the **Headphones** switch. The piano then plays along as a guide and the metronome keeps going, because only you can hear them.\n\n- Wired headphones work best\n- With Bluetooth headphones, choose the Mac's built-in microphone as the input in System Settings › Sound, or the sound quality drops"),
                L.checklist("Get set up", "Check each of these before your first exercise.",
                            items: [
                                "I'm in a reasonably quiet room: no music, television or fan close to the microphone.",
                                "I've allowed Piano Coach to use the microphone.",
                                "I'm about an arm's length from the Mac, facing it.",
                                "If I'm wearing headphones, the Headphones switch is on. If not, it is off.",
                                "I have a glass of water within reach.",
                            ]),
                L.info("Look after your voice",
                       "Your voice is part of your body, so treat practice like gentle exercise.\n\n- **Never push or strain.** Singing should feel easy. If a note feels tight, sing it more quietly or leave it out\n- **Stop if anything hurts** or your voice becomes hoarse, and rest it\n- **Sip water** as you practise\n- **Short and often** beats long and rare: ten minutes a day is plenty to begin with\n- **Warm up first**, starting in the middle of your range and working outwards\n\nA quiet, relaxed, in-tune note is always better than a loud forced one."),
            ]),
            lesson("voice.start.posture", "Posture for singing", "Stand tall and loose, then make your first sounds.", [
                L.info("Why posture matters",
                       "Your breath powers your voice, and your breath needs room. A tall, relaxed body lets your ribs and belly move freely.\n\nYou can sing sitting or standing. Standing is easier at first.\n\n- **Feet** about shoulder-width apart, weight even\n- **Knees** soft, not locked\n- **Spine** long, as if a string lifted the crown of your head\n- **Shoulders** down and back, loose\n- **Chin** level: not lifted for high notes, not tucked for low ones\n- **Jaw and tongue** relaxed",
                       links: [WebLink.video("singing posture for beginners")]),
                L.checklist("Posture check", "Stand in front of the Mac and scan from the floor up.",
                            items: [
                                "My feet are shoulder-width apart and my knees are not locked.",
                                "My spine is long and my chest is comfortably open, not puffed out.",
                                "My shoulders are down and loose. They don't rise when I breathe in.",
                                "My chin is level and my neck feels free.",
                                "My jaw hangs loosely and my teeth are slightly apart.",
                            ]),
                V.free("A gentle hum", "Close your lips lightly and **hum** any comfortable note: \"mmm\". Keep it quiet and easy, and feel a slight buzz on your lips.\n\nWatch your line appear on the display. Hum for a few seconds, breathing whenever you need to.",
                       seconds: 5, span: 0),
                V.free("Hum up and down", "Hum again, and this time let the pitch **wander a little higher and lower**, like a slow wave. See how the line follows you.",
                       seconds: 6, span: 3),
            ]),
            lesson("voice.start.range", "Find your range", "Show the app your lowest and highest comfortable notes.", [
                L.info("Everyone's range is different",
                       "Your **range** is the distance from the lowest note you can sing to the highest. It depends on your body, not on your talent, and it grows a little with practice.\n\nWhat matters here is your **comfortable** range: notes you can sing easily and quietly, without pressing or reaching.\n\nThe app uses it to place every exercise where your voice is happiest."),
                V.range("Your comfortable range",
                        "1. Sing down gently on \"ah\" to your **lowest comfortable note**, hold it steady, and set it as your lowest\n2. Sing up to your **highest comfortable note**, hold it steady, and set it as your highest\n\nDon't reach for extremes. If a note is breathy, croaky or tight, stop one or two notes before it."),
                L.info("Using your range",
                       "From now on, exercises are placed inside the range you just set.\n\n- If an exercise ever feels too high or too low, **change your range** with the voice range control on any singing step\n- **Come back to this lesson** whenever you like and measure again. Ranges widen with regular practice\n- Until you measure, the app assumes a medium-low voice, and the right note in **any octave** still counts"),
            ]),
            lesson("voice.start.first-note", "Your first notes", "What in tune, flat and sharp mean, and how to match a note.", [
                L.info("In tune, flat and sharp",
                       "When you sing exactly the pitch of the note, you are **in tune**.\n\n- A little too low is **flat**: your line sits under the bar\n- A little too high is **sharp**: your line sits over the bar\n\nSmall differences are measured in **cents**. There are 100 cents between one key on the piano and the next. In these lessons a note counts as in tune when you are within **50 cents** of it, and good singers aim for 10 to 20.\n\nTo fix a flat note, think the pitch higher and give a touch more breath. To fix a sharp note, relax and let it settle."),
                V.match("Match one note", "Listen to the note, then sing it on **\"ah\"** and hold it steady until the bar fills.\n\nIf your line is under the bar, slide up slowly until it turns green. If it is over the bar, slide down.",
                        "1", hold: 1.5, syllable: "ah"),
                V.match("The same note three times", "Sing the note, stop and breathe, then find it again. Each time, try to **land on it straight away** without sliding.",
                        "1 1 1", hold: 1.0, syllable: "ah"),
                V.match("A step up and back", "Three notes: the first note, the one above it, and back. Listen to each before you sing.",
                        "1 2 1", hold: 1.0, syllable: "ah"),
            ]),
            lesson("voice.start.display", "Following the moving notes", "Sing in time as the notes scroll past.", [
                L.info("Timed exercises",
                       "So far the app has waited for you. In a **timed** exercise the notes scroll towards a line, and you sing each one as it arrives.\n\n- Press **Start** or the space bar. You hear your starting note, then a count-in of four clicks\n- Press **Hear it** first if you want the piano to play the exercise\n- Breathe in during the count-in and start on the first note\n- If you miss a note, keep going and catch the next one\n\nEach note is scored on how much of it you sang in tune, so **hold every note for its full length**."),
                V.pattern("Two long notes", "Sing each note for two slow beats on \"ah\". Breathe after the second note if you need to.",
                          "1:h 1:h 2:h 2:h 1:w", bpm: 66, syllable: "ah"),
                V.pattern("Step up, step down", "One note per beat, moving by step. Keep the sound flowing from one note to the next.",
                          "1 2 1 2 1:h r:h 2 1 2 1 1:h", bpm: 72, syllable: "ah"),
                V.pattern("Three notes", "The first three notes of the scale, up and back down.",
                          "1 2 3:h 3 2 1:h", bpm: 72, syllable: "ah"),
                L.info("Just for fun: the Voice studio",
                       "The **Voice studio** in the sidebar has a live tuner that shows the note you are singing, a recorder, and **Auto-Tune**, which pulls your recorded voice onto the nearest notes. It is a good place to play with your voice between lessons."),
            ]),
        ])
    }

    // MARK: - Unit 2: Breath and support

    static var vBreath: CurriculumUnit {
        unit("voice.breath", "Breath and support", [
            lesson("voice.breath.low", "Breathing low", "Breathe with your belly and ribs, not your shoulders.", [
                L.info("Where the breath goes",
                       "Singers breathe **low**. As you breathe in, the **diaphragm** (a dome of muscle under your lungs) moves down, and your belly and lower ribs expand outwards. Your shoulders and upper chest stay still.\n\nTry it lying down or with a hand on your belly:\n\n- Breathe **in** through your nose or mouth: your hand moves **out**\n- Breathe **out**: your hand moves **in**\n\nThis is how you breathe when you are asleep. Singing simply makes it deliberate.",
                       links: [WebLink.video("diaphragmatic breathing for singing")]),
                L.checklist("Feel the low breath", "Stand tall with one hand on your belly and one on your upper chest.",
                            items: [
                                "When I breathe in, the hand on my belly moves out.",
                                "The hand on my chest and my shoulders stay almost still.",
                                "I can breathe in silently, without gasping.",
                                "I can feel my lower ribs widen at the sides and back.",
                                "I did five slow breaths like this without feeling dizzy. (If dizzy, breathe normally for a minute.)",
                            ]),
                V.match("Breathe, then sing", "Take one low, silent breath, then sing the note on \"ah\" and hold it for three seconds.",
                        "1", hold: 3, syllable: "ah"),
            ]),
            lesson("voice.breath.hiss", "Controlling the breath out", "Make one breath last with a steady hiss.", [
                L.info("Support",
                       "Singing uses a slow, steady stream of air. **Support** means letting the air out gradually instead of all at once: your belly moves in slowly while your ribs stay open as long as they can.\n\nA long **hiss** is the classic way to practise this, because you can hear at once whether the stream is steady.\n\nThe microphone can't judge a hiss, so time yourself and tick the boxes."),
                L.checklist("The steady hiss", "Breathe in low for four counts, then hiss \"sss\" as evenly as you can.",
                            items: [
                                "I hissed steadily for 10 seconds.",
                                "I hissed steadily for 15 seconds.",
                                "I hissed steadily for 20 seconds.",
                                "The hiss stayed the same loudness from start to finish, with no burst at the beginning.",
                                "My shoulders stayed down and my chest did not collapse.",
                            ]),
                V.match("A four-second note", "Now use the same steady stream of air for a sung note. Hold it for four seconds without wobbling.",
                        "1", hold: 4, syllable: "oo"),
                V.match("Two long notes", "Breathe low before each one.", "1 3", hold: 4, syllable: "oo"),
            ]),
            lesson("voice.breath.long-tones", "Long tones", "Hold notes steady for longer and longer.", [
                L.info("Why long tones",
                       "A **long tone** is one note held as steadily as you can. It trains breath control and pitch at the same time, and it is the first thing many singers do every day.\n\n- Start the note gently, exactly on pitch\n- Keep your line **flat and still** on the bar\n- Don't let the pitch sag at the end as the air runs low. Stop while it still sounds good"),
                V.match("Three seconds", "Hold each note for three seconds on \"ah\".", "1 2 3", hold: 3, syllable: "ah"),
                V.match("Five seconds", "Fewer notes, held longer. Take a full low breath before each.", "1 5", hold: 5, syllable: "ah"),
                V.match("Six seconds, closer tuning", "This time a note only counts within **35 cents**. Keep the line right in the middle of the bar.",
                        "1 3", hold: 6, syllable: "oo", tolerance: 35),
                L.checklist("How did it feel?", "Think back over the long tones.",
                            items: [
                                "I had air left at the end of each note.",
                                "My throat felt open and relaxed, not squeezed.",
                                "The loudness stayed about the same through each note.",
                            ]),
            ]),
            lesson("voice.breath.sirens", "Sirens and lip trills", "Slide through your whole range with no effort.", [
                L.info("Sliding",
                       "A **siren** is a smooth slide from low to high and back, like an ambulance, on \"oo\" or \"ng\". A **lip trill** is the same slide while your lips flutter: \"brrr\", like a horse.\n\nBoth warm up the whole voice gently and smooth out the join between your lower and higher sounds. There are no target notes: just slide and watch the line.",
                       links: [WebLink.video("lip trill vocal exercise how to")]),
                V.free("Small sirens", "On **\"oo\"**, slide up a little and back down, slowly, several times. Keep it quiet.",
                       seconds: 8, span: 5),
                V.free("Lip trills", "Blow air through loose lips so they flutter, add your voice, and slide up and down. If the lips stop, press a fingertip lightly into each cheek.",
                       seconds: 8, span: 5),
                V.free("Big sirens", "Now slide from near the bottom of your range to near the top and back, on \"ng\" (as in \"sing\") or \"oo\". Never push at the top: let it get lighter as it gets higher.",
                       seconds: 10, span: 9),
            ]),
            lesson("voice.breath.onset", "Starting notes cleanly", "Begin each note on pitch, without a slide or a push.", [
                L.info("The onset",
                       "The **onset** is the moment a note begins. Aim for a clean start: breath and sound begin together, exactly on the pitch.\n\n- A **breathy** start leaks air before the sound: \"hhhah\"\n- A **hard** start slams the note with a click in the throat\n- A **balanced** start is in between: clear and gentle\n\nShort notes on **\"ha\"** are good practice. Each one starts with a small pulse from your belly, like a quiet laugh."),
                V.pattern("Short notes on one pitch", "Four short \"ha\" sounds, then a long one. Let your belly bounce on each.",
                          "1:e r:e 1:e r:e 1:e r:e 1:e r:e 1:h", bpm: 76, syllable: "ha"),
                V.pattern("Short notes, moving", "The same bounce, now stepping up and down.",
                          "1:e r:e 2:e r:e 3:e r:e 2:e r:e 1:h", bpm: 76, syllable: "ha"),
                V.pattern("Clean starts on long notes", "Each note starts after a rest. Hear the pitch in your head, then land on it without sliding.",
                          "1:h r 3:h r 5:h r 3:h r 1:h", bpm: 72, syllable: "ah", tolerance: 40),
            ]),
        ])
    }

    // MARK: - Unit 3: Matching pitch

    static var vMatch: CurriculumUnit {
        unit("voice.match", "Matching pitch", [
            lesson("voice.match.single", "Single notes", "Hear a note, then land on it.", [
                L.info("Hear it first",
                       "Matching pitch is a skill of the **ear** as much as the voice. Before you sing, hear the note clearly in your head, as if you were about to hum along with it.\n\n- Listen to the whole note\n- Imagine yourself singing it\n- Then sing, quietly, and adjust\n\nIf you can't find a note, slide slowly up or down on \"oo\" until the line reaches the bar. With practice the slide gets shorter until you land on the note directly."),
                V.match("Notes in the middle", "Three different notes. Press **Hear it** as often as you need.", "1 3 2", hold: 1.0, syllable: "oo"),
                V.match("Higher and lower", "These are further apart. Listen carefully before each one.", "1 5 3", hold: 1.0, syllable: "oo"),
                V.match("Below the first note", "The second note is lower than where you start.", "1 5, 1", hold: 1.0, syllable: "oo"),
            ]),
            lesson("voice.match.neighbours", "Neighbour notes", "Small moves up and down from a home note.", [
                L.info("Steps and half steps",
                       "Most melodies move to the note next door. A **whole step** (do to re) is two keys apart on the piano. A **half step** (ti to do) is one key apart, the smallest move in most music.\n\nSmall moves need small adjustments. Singers often overshoot them, so think of nudging the pitch, not jumping."),
                V.match("A step above", "Home, the note above, and home again.", "1 2 1", hold: 1.0),
                V.match("A half step below", "Home, the note just below, and home again. The lower note is very close.", "1 7, 1", hold: 1.0),
                V.pattern("Around the home note", "Up a step, home, down a half step, home.", "1 2 1 7, 1:w", bpm: 66),
                V.pattern("Neighbours, closer tuning", "The same shape, scored within **35 cents**.", "1:h 2:h 1:h 7,:h 1:w", bpm: 66, tolerance: 35),
            ]),
            lesson("voice.match.slides", "Sliding to a note", "Use a slide to find a pitch, then learn to do without it.", [
                L.info("The slide as a tool",
                       "Sliding into a note is a good way to **find** it. It is also a habit to grow out of, because in most songs notes should start on pitch.\n\nIn this lesson you slide on purpose, then repeat the same notes without sliding."),
                V.free("Slide up slowly", "On \"oo\", slide up as **slowly** as you can, then down again. Slow slides teach fine control.", seconds: 8, span: 4),
                V.match("Slide, then hold", "Start below each note and slide up until the line turns green, then hold it still.", "3 5", hold: 1.5, syllable: "oo"),
                V.match("No slide", "The same two notes. Hear each one first, then start right on it.", "3 5", hold: 1.5, syllable: "oo", tolerance: 40),
            ]),
            lesson("voice.match.three", "Three-note patterns", "Short shapes sung in time.", [
                L.info("Shapes",
                       "Melodies are made of small shapes: up by step, down by step, a skip and back. Learning to sing these shapes in tune is most of what it takes to sing songs in tune.\n\nThe syllables on the notes are **solfège**: **do, re, mi, fa, sol**. The next unit explains them fully. For now, just sing the syllable shown."),
                V.pattern("Up and down by step", "Do, re, mi and back.", "1 2 3 2 1:h", bpm: 72),
                V.pattern("A skip", "Do to mi skips over re. Then step back down.", "1 3 2 1:h r 1 3 2 1:h", bpm: 72),
                V.pattern("Down from the top", "Start on sol and come down by step.", "5 4 3 2 1:h", bpm: 72),
                V.pattern("Skips up and down", "Do, mi, sol and back: the notes of a chord.", "1 3 5 3 1:h", bpm: 72),
            ]),
            lesson("voice.match.memory", "Hear, then sing", "Sing short patterns from memory, with no help while you sing.", [
                L.info("Singing from memory",
                       "In these exercises the piano does **not** play along, even with headphones on. Press **Hear it**, listen to the whole pattern, then press Start and sing it back.\n\nThis is how you learn a tune by ear: listen, remember, sing."),
                V.pattern("Three notes from memory", "Listen first with **Hear it**, then sing it back.", "1 2 3:h", bpm: 72, guide: false),
                V.pattern("Five notes from memory", "A little longer.", "1 3 2 1 1:h", bpm: 72, guide: false),
                V.pattern("A phrase from memory", "Listen twice if you need to.", "3 2 1 2 3 3 3:h", bpm: 76, guide: false),
                V.pattern("With a skip", "Notice where the tune jumps.", "1 1 5 5 3:h 1:h", bpm: 76, guide: false),
            ]),
        ])
    }

    // MARK: - Unit 4: Scales and solfège

    static var vScales: CurriculumUnit {
        unit("voice.scales", "Scales and solfège", [
            lesson("voice.scales.solfege", "Do, re, mi", "The solfège syllables and the first three notes.", [
                L.info("Solfège",
                       "**Solfège** gives each note of the scale a syllable:\n\n**do  re  mi  fa  sol  la  ti  do**\n\n**Do** is the home note of the key. The syllables name each note's place in the scale, not a fixed key on the piano, so the same syllables work in any key. That suits singing, where the key moves to fit your voice.\n\nSinging on syllables also keeps your mouth moving through clear vowels: oh, ay, ee, ah."),
                V.match("Do, re, mi", "Hold each one until the bar fills.", "1 2 3", hold: 1.0),
                V.pattern("Up and down", "Sing the syllables shown on the notes.", "1 2 3 2 1 2 3 2 1:w", bpm: 76),
                V.pattern("Skipping re", "Do to mi and back, then all three.", "1 3 1 3 1 2 3:h", bpm: 76),
            ]),
            lesson("voice.scales.five", "The five-note scale", "Do to sol and back: the core of most warm-ups.", [
                L.info("Five notes",
                       "The first five notes of the major scale, **do re mi fa sol**, fit comfortably in almost every voice. Between **mi** and **fa** is a **half step**, smaller than the other steps. Singers often sing fa too high, so listen for it."),
                V.match("Mi and fa", "These two are only a half step apart.", "3 4 3", hold: 1.0),
                V.pattern("Up five", "Climb from do to sol.", "1 2 3 4 5:h", bpm: 76),
                V.pattern("Down five", "And back down.", "5 4 3 2 1:h", bpm: 76),
                V.pattern("Up and down", "One breath for the whole shape if you can.", "1 2 3 4 5 4 3 2 1:w", bpm: 80),
            ]),
            lesson("voice.scales.major", "The major scale", "All eight notes, do to do.", [
                L.info("The whole scale",
                       "The full **major scale** adds **la** and **ti** and arrives on **do** an octave above where you began.\n\n- **Ti to do** at the top is the second half step. Ti leans strongly upwards: sing it high and bright\n- As you climb, let the sound get **lighter**, not louder\n- Take a breath after sol if you need one"),
                V.pattern("The upper half", "Sol, la, ti, do: the top four notes.", "5 6 7 1':h r 1' 7 6 5:h", bpm: 76),
                V.pattern("Up the scale", "Do to do.", "1 2 3 4 5 6 7 1':h", bpm: 80),
                V.pattern("Down the scale", "From the top. Don't let the pitch sag as you come down.", "1' 7 6 5 4 3 2 1:h", bpm: 80),
                V.pattern("Up and down", "The complete scale both ways.", "1 2 3 4 5 6 7 1' 7 6 5 4 3 2 1:h", bpm: 84),
            ]),
            lesson("voice.scales.minor", "The minor scale", "A darker scale with three lowered notes.", [
                L.info("Minor",
                       "The **natural minor scale** lowers the third, sixth and seventh notes of the major scale by a half step. That gives it a darker, sadder colour.\n\nThe lowered notes have their own syllables: **me** (may), **le** (lay) and **te** (tay).\n\n**do  re  me  fa  sol  le  te  do**\n\nThe half steps are now between **re and me** and between **sol and le**."),
                V.match("Mi and me", "Major third, then minor third. Hear how the colour changes.", "1 3 1 b3=me", hold: 1.0),
                V.pattern("Five notes in minor", "Do, re, me, fa, sol and back.", "1 2 b3=me 4 5 4 b3=me 2 1:w", bpm: 76),
                V.pattern("The minor scale, up", "All eight notes.", "1 2 b3=me 4 5 b6=le b7=te 1':h", bpm: 80),
                V.pattern("The minor scale, up and down", "Both directions.", "1 2 b3=me 4 5 b6=le b7=te 1' b7=te b6=le 5 4 b3=me 2 1:h", bpm: 80),
            ]),
            lesson("voice.scales.thirds", "The scale in thirds", "Skip up, step back: a classic tuning exercise.", [
                L.info("Thirds",
                       "Singing the scale **in thirds** means skipping one note each time: do–mi, re–fa, mi–sol and so on. It trains you to hear two notes ahead and keeps every skip in tune."),
                V.pattern("Thirds, the first half", "Skip up, then step back and skip again.", "1 3 2 4 3 5:h", bpm: 76),
                V.pattern("Thirds, going up", "All the way to the top do.", "1 3 2 4 3 5 4 6 5 7 6 1':h", bpm: 80),
                V.pattern("Thirds, coming down", "The same idea in reverse.", "1' 6 7 5 6 4 5 3 4 2 3 1:h", bpm: 80),
                V.pattern("Thirds, closer tuning", "Up in thirds, scored within **35 cents**.", "1 3 2 4 3 5 4 6 5 7 6 1':h", bpm: 76, tolerance: 35),
            ]),
            lesson("voice.scales.review", "Scale review", "Major and minor from memory.", [
                L.info("Putting it together",
                       "This review mixes the scales you know. The last two are sung **from memory**: press **Hear it** if you need a reminder, then sing without the piano."),
                V.pattern("Major, up and down", "The whole major scale, a little faster than before.", "1 2 3 4 5 6 7 1' 7 6 5 4 3 2 1:h", bpm: 88),
                V.pattern("Minor, up and down", "The natural minor scale. Remember me, le and te.", "1 2 b3=me 4 5 b6=le b7=te 1' b7=te b6=le 5 4 b3=me 2 1:h", bpm: 88),
                V.pattern("Five notes from memory", "Do to sol and back, without the piano.", "1 2 3 4 5 4 3 2 1:w", bpm: 84, guide: false),
                V.pattern("Major scale from memory", "Do to do, without the piano.", "1 2 3 4 5 6 7 1':h", bpm: 84, guide: false),
            ]),
        ])
    }

    // MARK: - Unit 5: Intervals

    static var vIntervals: CurriculumUnit {
        unit("voice.intervals", "Intervals", [
            lesson("voice.intervals.seconds-thirds", "Seconds and thirds", "The smallest steps and skips, from do.", [
                L.info("Intervals",
                       "An **interval** is the distance between two notes. Singers learn each one by its sound, often by linking it to the start of a tune they know.\n\n- **Major second** (do–re): a whole step. *Frère Jacques* begins with one\n- **Major third** (do–mi): a bright skip. *When the Saints Go Marching In* begins with one\n\nSing each interval slowly and listen to the distance."),
                V.match("Major second", "Do, then re.", "1 2", hold: 1.2),
                V.match("Major third", "Do, then mi.", "1 3", hold: 1.2),
                V.pattern("Seconds and thirds", "Each interval up and back.", "1:h 2:h 1:w r 1:h 3:h 1:w", bpm: 76),
                V.pattern("From memory", "Listen with **Hear it**, then sing without the piano.", "1:h 3:h 1:h 2:h 1:w", bpm: 76, guide: false),
            ]),
            lesson("voice.intervals.fourths-fifths", "Fourths and fifths", "Open, strong leaps.", [
                L.info("Perfect fourth and fifth",
                       "- **Perfect fourth** (do–fa): the start of *Here Comes the Bride*, and the first two notes of *Amazing Grace*\n- **Perfect fifth** (do–sol): the leap in *Twinkle, Twinkle, Little Star* between the second and third notes\n\nBoth sound open and strong. For bigger leaps, hear the top note in your head before you leave the bottom one, and don't push: the higher note needs faster air, not more force."),
                V.match("Perfect fourth", "Do, then fa.", "1 4", hold: 1.2),
                V.match("Perfect fifth", "Do, then sol.", "1 5", hold: 1.2),
                V.pattern("Fourths and fifths", "Each interval up and back.", "1:h 4:h 1:w r 1:h 5:h 1:w", bpm: 76),
                V.pattern("Fill it in, then leap", "Sing up by step to sol, then leap straight there.", "1 2 3 4 5:h r:h 1:h 5:h 1:w", bpm: 80),
            ]),
            lesson("voice.intervals.sixths-octave", "Sixths and the octave", "The widest leaps in most songs.", [
                L.info("Major sixth and octave",
                       "- **Major sixth** (do–la): the opening leap of *My Bonnie Lies Over the Ocean*\n- **Octave** (do–do): the same note higher up. *Take Me Out to the Ball Game* begins with one\n\nOn wide leaps, keep your chin level and your throat open. The top note should feel like it floats, not like you climbed to it."),
                V.match("Major sixth", "Do, then la.", "1 6", hold: 1.2),
                V.match("Octave", "Low do, then high do.", "1 1'", hold: 1.2),
                V.pattern("Sixths and octaves", "Each leap up and back.", "1:h 6:h 1:w r 1:h 1':h 1:w", bpm: 76),
                V.pattern("Stepping stones to the octave", "Do, mi, sol, do: each leap a little higher.", "1 3 5 1':h 5 3 1:h", bpm: 80),
            ]),
            lesson("voice.intervals.small", "Half steps and minor thirds", "The small intervals that give music its colour.", [
                L.info("Minor second and minor third",
                       "- **Minor second** (ti–do): a half step, the smallest interval. It sounds tense and close\n- **Minor third** (do–me): three half steps. *Greensleeves* begins with one, and so does Brahms's *Lullaby*\n\nSmall intervals are harder to tune than big ones, because there is less room for error. Listen closely."),
                V.match("Half step", "Do, down to ti, and back.", "1 7, 1", hold: 1.2),
                V.match("Minor third", "Do, then me.", "1 b3=me", hold: 1.2),
                V.pattern("Major and minor thirds", "Compare the two: mi, then me.", "1:h 3:h 1:w r 1:h b3:h=me 1:w", bpm: 76),
                V.pattern("Half steps", "Scored within **35 cents**.", "1:h 7,:h 1:w r 3:h 4:h 3:w", bpm: 72, tolerance: 35),
            ]),
            lesson("voice.intervals.triads", "Chords with your voice", "Sing the notes of major and minor chords one at a time.", [
                L.info("Arpeggios",
                       "A chord sung one note at a time is an **arpeggio**. The **major** chord is do–mi–sol. Lower the middle note to me and it becomes **minor**.\n\nArpeggios are made of thirds, so they pull together everything in this unit."),
                V.pattern("Major arpeggio", "Do, mi, sol and back.", "1 3 5 3 1:h", bpm: 80),
                V.pattern("Minor arpeggio", "Do, me, sol and back.", "1 b3=me 5 b3=me 1:h", bpm: 80),
                V.pattern("Major, then minor", "One after the other.", "1 3 5 3 1:h r:h 1 b3=me 5 b3=me 1:h", bpm: 80),
                V.pattern("Up to the octave", "Do, mi, sol, high do, and back down.", "1 3 5 1' 5 3 1:h", bpm: 84),
            ]),
            lesson("voice.intervals.review", "Interval review", "Every interval from do, mixed up.", [
                L.info("Mixed intervals",
                       "Each exercise goes from **do** to another note and back. Name the interval to yourself before you sing it. The last two are from memory."),
                V.pattern("Growing leaps", "Second, third, fourth, fifth.", "1 2:h 1 3:h 1 4:h 1 5:h 1:w", bpm: 80),
                V.pattern("Wide leaps", "Fifth, sixth, octave.", "1 5:h 1 6:h 1 1':h 1:w", bpm: 80),
                V.pattern("Mixed, from memory", "Fifth, third, fourth. Listen with **Hear it**, then sing without the piano.", "1 5:h 1 3:h 1 4:h 1:w", bpm: 80, guide: false),
                V.pattern("Mixed and wide, from memory", "Octave, third, sixth, without the piano.", "1 1':h 1 3:h 1 6:h 1:w", bpm: 80, guide: false),
            ]),
        ])
    }

    // MARK: - Unit 6: Warm-ups and agility

    static var vWarmups: CurriculumUnit {
        let up5 = [0, 1, 2, 3, 4]
        return unit("voice.warmups", "Warm-ups and agility", [
            lesson("voice.warmups.five-note", "The rising five-note warm-up", "The most common warm-up of all, moving up by half steps.", [
                L.info("How warm-ups work",
                       "A classic warm-up takes a short pattern and repeats it, starting a **half step higher** each time. Your voice is eased gradually towards the top of its range.\n\n- Breathe in the two beats between repetitions\n- Keep the same easy sound as it rises: lighter, not louder\n- If a repetition feels too high, **stop singing and wait** for the exercise to finish, or lower the top of your range"),
                V.free("Lip trill first", "Start with a few lip trills or sirens to get the air moving.", seconds: 8, span: 5),
                V.pattern("Five notes, rising", "Up and down five notes on **\"mah\"**, five times, each a half step higher.",
                          "1:e 2:e 3:e 4:e 5:e 4:e 3:e 2:e 1:h", bpm: 84, shifts: up5, syllable: "mah"),
                V.pattern("Five notes on \"nee\"", "The same pattern on a bright **\"nee\"**. Keep your jaw loose.",
                          "1:e 2:e 3:e 4:e 5:e 4:e 3:e 2:e 1:h", bpm: 88, shifts: up5, syllable: "nee"),
            ]),
            lesson("voice.warmups.arpeggio", "Arpeggio warm-ups", "Skips instead of steps, rising by half steps.", [
                L.info("Skipping warm-ups",
                       "Arpeggio warm-ups cover more ground with fewer notes, so they stretch the range a little further. Keep each note connected to the next, as if drawing one curved line."),
                V.pattern("Do–mi–sol–mi–do, rising", "On **\"ah\"**, five times.", "1 3 5 3 1:h", bpm: 88, shifts: up5, syllable: "ah"),
                V.pattern("To the octave, rising", "Do, mi, sol, high do and back, four times. Let the top note be light.",
                          "1:e 3:e 5:e 1':e 5:e 3:e 1:h", bpm: 84, shifts: [0, 1, 2, 3], syllable: "ah"),
                V.pattern("Coming back down", "The first pattern again, now starting high and moving **down** by half steps to settle the voice.",
                          "1 3 5 3 1:h", bpm: 88, shifts: [4, 3, 2, 1, 0], syllable: "oh"),
            ]),
            lesson("voice.warmups.vowels", "Vowels on one note", "Keep the pitch still while the vowel changes.", [
                L.info("Five vowels",
                       "Songs are sung mostly on **vowels**, and each vowel shapes the mouth differently. The skill is to change the vowel without changing the pitch or the loudness.\n\n**mee  may  mah  moh  moo**\n\nKeep the tip of your tongue resting behind your bottom teeth, and change the vowel with as little jaw movement as you can."),
                V.pattern("Mee, may, mah, moh, moo", "All five vowels on one note, two beats each.",
                          "1:h=mee 1:h=may 1:h=mah 1:h=moh 1:h=moo", bpm: 72),
                V.pattern("Vowels, rising", "The same on each of five rising notes. Watch that the line stays flat as the vowel changes.",
                          "1=mee 1=may 1=mah 1=moh 1:h=moo", bpm: 80, shifts: up5, tolerance: 40),
                V.pattern("Vowels on a scale", "One vowel per note, up and down five notes.",
                          "1=mee 2=may 3=mah 4=moh 5=moo 4=moh 3=mah 2=may 1:h=mee", bpm: 76),
            ]),
            lesson("voice.warmups.staccato", "Staccato", "Short, bouncing notes that wake up the breath.", [
                L.info("Short notes",
                       "**Staccato** notes are short and separate. Each one comes from a small bounce of the belly, not from the throat. Staccato sharpens pitch accuracy, because there is no time to slide into a note."),
                V.pattern("Staccato arpeggio", "Short \"ha\" on each note, then a long last note.",
                          "1:e r:e 3:e r:e 5:e r:e 3:e r:e 1:h", bpm: 84, syllable: "ha"),
                V.pattern("Staccato arpeggio, rising", "Four times, each a half step higher.",
                          "1:e r:e 3:e r:e 5:e r:e 3:e r:e 1:h", bpm: 88, shifts: [0, 1, 2, 3], syllable: "ha"),
                V.pattern("Short, then smooth", "The arpeggio staccato, then the same notes joined smoothly on \"ah\".",
                          "1:e=ha r:e 3:e=ha r:e 5:e=ha r:e 3:e=ha r:e 1:h=ha r:h 1=ah 3=ah 5=ah 3=ah 1:h=ah", bpm: 84),
            ]),
            lesson("voice.warmups.agility", "Agility", "Faster runs, kept light and even.", [
                L.info("Singing quickly",
                       "**Agility** is moving through notes quickly and cleanly. The secret is to sing **lightly**: a heavy sound can't move fast.\n\nStart each run slowly in your head. If the notes smear together, go back to the slower exercise."),
                V.pattern("Five-note run", "Up and down five notes in eighth notes.", "1:e 2:e 3:e 4:e 5:e 4:e 3:e 2:e 1:h", bpm: 100, syllable: "ah"),
                V.pattern("Nine-note run", "Up past the octave to re and back down.",
                          "1:e 2:e 3:e 4:e 5:e 6:e 7:e 1':e 2':e 1':e 7:e 6:e 5:e 4:e 3:e 2:e 1:h", bpm: 96, syllable: "ah"),
                V.pattern("Runs, rising", "The five-note run, five times, a half step higher each time.",
                          "1:e 2:e 3:e 4:e 5:e 4:e 3:e 2:e 1:h", bpm: 108, shifts: up5, syllable: "ee"),
                V.pattern("Turning figure", "A twisting pattern that changes direction often.",
                          "1:e 2:e 3:e 1:e 2:e 3:e 4:e 2:e 3:e 4:e 5:e 3:e 4:e 3:e 2:e 7,:e 1:h", bpm: 92, syllable: "ah"),
            ]),
            lesson("voice.warmups.routine", "A daily warm-up", "Five minutes to do before any singing.", [
                L.info("Your routine",
                       "This lesson is a complete short warm-up. Do it before the Songs unit, or any time you are about to sing.\n\n1. **Body and breath**: posture check and three low breaths\n2. **Sirens**: lip trills through your range\n3. **Five-note scale**, rising\n4. **Arpeggio**, rising\n5. **Cool down**, coming back to the middle\n\nGo gently for the first minute. Your voice works better warm."),
                L.checklist("Body and breath", "Before you make a sound.",
                            items: [
                                "I'm standing tall with loose knees, shoulders and jaw.",
                                "I've taken three slow, low breaths.",
                                "I've had a sip of water.",
                            ]),
                V.free("Sirens", "Lip trills or \"oo\" sirens, low to high and back.", seconds: 10, span: 7),
                V.pattern("Five notes, rising", "On \"mah\".", "1:e 2:e 3:e 4:e 5:e 4:e 3:e 2:e 1:h", bpm: 88, shifts: up5, syllable: "mah"),
                V.pattern("Arpeggio, rising", "On \"ah\".", "1 3 5 3 1:h", bpm: 88, shifts: up5, syllable: "ah"),
                V.pattern("Cool down", "A slow descending scale on \"oo\", moving down by half steps.", "5 4 3 2 1:h", bpm: 72, shifts: [2, 1, 0], syllable: "oo"),
            ]),
        ])
    }
}
