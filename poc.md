# RecallAI - Proof of Concept Plan (Revised for Clarity)

This document outlines the tasks for the Proof of Concept (PoC) development of RecallAI. Each feature will be implemented and tested sequentially. The primary goal is to determine feature feasibility; UI/UX, performance tuning, and battery optimization are **not** primary concerns for this PoC.

## Core PoC Features:

- [ ] **Task 1: Call Recording**
    - [ ] **1.1. Integration Point Identification:** Identify the existing class(es) or service(s) in the Dialer codebase responsible for managing call states (e.g., call start, active, end). This is where recording logic will be initiated and terminated. (Hint: Based on initial search, `CallService.kt` (extends `InCallService`) and `CallManager.kt` are key candidates. `CallActivity.kt` for UI/permissions).
    - [ ] **1.2. Proposed Implementation Strategy:**
        - **New Class:** Create `CallRecorder.kt` in a relevant package (e.g., `com.goodwy.dialer.recorders` or `com.goodwy.dialer.helpers`). This class will encapsulate all `android.media.MediaRecorder` setup, start, stop, and file management logic.
        - **Modify `CallService.kt` (and/or `CallManager.kt`):**
            - Instantiate `CallRecorder` when `CallService` is active.
            - In `CallService` (or `CallManager` if it directly handles individual call state changes like `onStateChanged` from `android.telecom.Call.Callback`), detect when a call becomes active (e.g., state `Call.STATE_ACTIVE`). On this event, instruct `CallRecorder` to start a new recording.
            - Detect when a call disconnects (e.g., state `Call.STATE_DISCONNECTED`). On this event, instruct `CallRecorder` to stop and save the current recording.
        - **Modify `CallActivity.kt` (or a central permission utility if one exists):** Implement the runtime request for `RECORD_AUDIO` permission if not already handled. This could be done in `onCreate` or `onResume` of `CallActivity`, or before initiating an outgoing call/answering an incoming call.
        - **Modify `AndroidManifest.xml`:** Add `<uses-permission android:name="android.permission.RECORD_AUDIO" />`.
    - [ ] **1.3. Recording Implementation:** Implement audio recording for both incoming and outgoing calls using `android.media.MediaRecorder` (as detailed in `CallRecorder.kt`).
        - Configure `MediaRecorder` to use `MediaRecorder.AudioSource.VOICE_COMMUNICATION`. This source is intended for capturing uplink + downlink voice communication. If this source proves problematic or unavailable on test devices, fallback to `MediaRecorder.AudioSource.MIC` (for user's side only) as a PoC compromise and document this limitation.
        - Set output format to `MediaRecorder.OutputFormat.AMR_NB`.
        - Set audio encoder to `MediaRecorder.AudioEncoder.AMR_NB`.
    - [ ] **1.4. Storage & Naming:** (Handled within `CallRecorder.kt`)
        - Store audio files in the application-specific external storage directory: `context.getExternalFilesDir(Environment.DIRECTORY_RECORDINGS)`.
        - Name files using the convention: `YYYYMMDD_HHMMSS_<phonenumber_if_available_else_unknown>_call.amr`. For `<phonenumber>`, use the actual number if accessible (e.g., from `Call.Details`), otherwise use "unknown".
    - [ ] **1.5. Permissions Handling:** (As per strategy in 1.2)
        - Ensure the `RECORD_AUDIO` permission is declared in `AndroidManifest.xml`.
        - Implement a runtime request for `RECORD_AUDIO` permission. For PoC, this can be requested when the app starts or when the `CallActivity` (or equivalent in-call screen) is launched. Assume permission is granted after the first request for PoC simplicity.
        - Note: For writing to `getExternalFilesDir()`, explicit `WRITE_EXTERNAL_STORAGE` is generally not needed on Android Q+ but ensure manifest doesn't restrict other necessary storage access if `maxSdkVersion` for `WRITE_EXTERNAL_STORAGE` is used.
    - [ ] **1.6. Testing:**
        - Make/receive calls and verify that `.amr` files are created in the specified directory with the correct naming convention.
        - Confirm files have a non-zero size.
        - Play back the recorded audio files using a standard media player to ensure voice is captured. If `VOICE_COMMUNICATION` worked, verify if both sides of the conversation are present.
    - [ ] **1.7. Build, Deploy & User Test:** Ask the user (Darek) to build the app, deploy it to a device, and manually test the call recording feature based on the criteria in 1.6.

- [ ] **Task 2: Post-Call Transcription (Polish STT)**
    - [ ] **2.1. Integration Point Identification:** Triggered after call recording is complete. Logic can reside in `CallRecorder.kt` upon successful save, or be initiated by `CallService.kt`/`CallManager.kt`.
    - [ ] **2.2. Proposed Implementation Strategy:**
        - **New Class:** Create `TranscriptionManager.kt` (e.g., in `com.goodwy.dialer.transcription`). This class will handle:
            - Setting up `android.speech.SpeechRecognizer`.
            - Configuring it for Polish (`pl-PL`).
            - Processing the audio file URI.
            - Receiving transcription results.
            - Saving the transcript to a text file.
        - **Modify `CallRecorder.kt` (or `CallService.kt`/`CallManager.kt`):** After a recording is successfully saved (e.g., in `CallRecorder.stopRecordingAndSave()`), obtain the URI of the saved audio file and pass it to an instance of `TranscriptionManager` to start the transcription process.
    - [ ] **2.3. Triggering Transcription:** Implement logic to automatically start transcription *after* a call recording (from Task 1) is successfully saved and the call has ended (as per strategy in 2.2).
    - [ ] **2.4. STT Implementation:** Utilize `android.speech.SpeechRecognizer` for transcription (within `TranscriptionManager.kt`).
        - Create an `Intent` for `RecognizerIntent.ACTION_RECOGNIZE_SPEECH`.
        - Set `RecognizerIntent.EXTRA_LANGUAGE_MODEL` to `RecognizerIntent.LANGUAGE_MODEL_FREE_FORM`.
        - **Crucially, set `RecognizerIntent.EXTRA_LANGUAGE` to `"pl-PL"` for Polish.**
        - Pass the URI of the saved audio file to the `SpeechRecognizer` if the API supports direct file input (e.g. `RecognizerIntent.EXTRA_AUDIO_DATA` with offline capabilities or an equivalent mechanism if available and feasible for PoC, research required). If direct file input to `SpeechRecognizer` is not straightforward for offline/already-recorded files, investigate if `SpeechRecognizer` can be made to listen to playback of the recorded audio via `MediaPlayer` and an `AudioTrack` loopback, or if a simpler approach for PoC is to use it with microphone input on a test device playing the recording. *Initial approach: research direct file input or URI-based recognition.*
        - Assume an internet connection is available for STT during the PoC.
    - [ ] **2.5. Storing Transcription:** (Handled within `TranscriptionManager.kt`)
        - Store the resulting transcription text in a `.txt` file.
        - Name the text file identically to its corresponding audio file, but with a `.txt` extension (e.g., `YYYYMMDD_HHMMSS_<phonenumber>_call.txt`), and save it in the same directory.
    - [ ] **2.6. Testing:**
        - Use audio files recorded in Task 1 (featuring Polish speech).
        - Verify that `.txt` files are generated alongside audio files.
        - Review the content of the text files to confirm that Polish speech is transcribed (accuracy is secondary to successful transcription for PoC).
    - [ ] **2.7. Build, Deploy & User Test:** Ask the user (Darek) to build the app, deploy it to a device, and manually test the post-call transcription feature using calls with Polish speech, verifying against criteria in 2.6.

- [ ] **Task 3: Real-time UI Transcription (Polish STT - User's Microphone)**
    - [ ] **3.1. Integration Point:** This will be integrated into the main in-call UI Activity, which is `CallActivity.kt`.
    - [ ] **3.2. Proposed Implementation Strategy:**
        - **Modify `CallActivity.kt`:**
            - Add a `private lateinit var speechRecognizer: SpeechRecognizer` and a `private lateinit var transcriptionTextView: TextView` (or similar `View` for displaying text).
            - In `onCreate` or a suitable lifecycle method, initialize `speechRecognizer`.
            - When the call becomes active (this state is likely already observed by `CallActivity` to update its UI), start `speechRecognizer.startListening(...)` with an `Intent` configured for Polish STT (similar to Task 2.4 but for live microphone input).
            - Implement `RecognitionListener` within `CallActivity` or as a nested/separate listener class.
            - In `onPartialResults` or `onResults` of the listener, append the recognized text to `transcriptionTextView`.
            - Ensure `speechRecognizer.stopListening()` and `speechRecognizer.destroy()` are called at appropriate times (e.g., when the call ends or `CallActivity` is destroyed).
        - **Modify Layout File:** Add the `TextView` (e.g., with an ID like `@+id/real_time_transcription_view`) to the layout XML file used by `CallActivity.kt`.
    - [ ] **3.3. Real-time STT Implementation:** (As per strategy in 3.2)
        - Utilize `android.speech.SpeechRecognizer` initiated when the call becomes active.
        - **For this PoC, the primary goal is to capture and transcribe the *local user's audio via the device microphone* during the call.**
        - Configure `SpeechRecognizer` for Polish (`"pl-PL"`) as in Task 2.4.
        - The `SpeechRecognizer` will listen for partial and final results.
    - [ ] **3.4. UI Display:** (As per strategy in 3.2)
        - On the in-call UI (`CallActivity.kt`), add a simple `TextView` (or similar, e.g., a non-editable `EditText` for scrolling).
        - As `SpeechRecognizer` provides results (partial or final), append them to this `TextView`.
        - Focus on demonstrating text appearing in (near) real-time. UI elegance is not a PoC goal.
    - [ ] **3.5. Testing:**
        - During an active call, speak in Polish.
        - Verify that your spoken words appear in the designated `TextView` on the in-call UI within a few seconds.
        - Ensure this does not significantly disrupt the ongoing call audio or recording (Task 1).
    - [ ] **3.6. Build, Deploy & User Test:** Ask the user (Darek) to build the app, deploy it to a device, and manually test the real-time UI transcription feature during a call with Polish speech, verifying against criteria in 3.5.

- [ ] **Task 4: Text-to-Speech (TTS) Audio Playback in Call (Polish)**
    - [ ] **4.1. Integration Point:** Logic to be triggered from `CallService.kt` or `CallManager.kt` when a call transitions to an active state.
    - [ ] **4.2. Proposed Implementation Strategy:**
        - **New Class:** Create `TTSPlayer.kt` (e.g., in `com.goodwy.dialer.tts` or `com.goodwy.dialer.helpers`). This class will:
            - Initialize `android.speech.tts.TextToSpeech`, setting the language to Polish.
            - Handle `synthesizeToFile()` to generate the audio for "Cześć, tu Darek".
            - Initialize `android.media.MediaPlayer`.
            - Configure `MediaPlayer` with `AudioAttributes` for `STREAM_VOICE_CALL`.
            - Manage `AudioManager.requestAudioFocus()` and `abandonAudioFocus()`.
            - Contain methods to `prepareAndPlayGreeting(delayMillis: Long)`.
        - **Modify `CallService.kt` (or `CallManager.kt`):**
            - When a call becomes active (e.g., state `Call.STATE_ACTIVE`), get an instance of `TTSPlayer` (it could be a singleton or instantiated as needed).
            - Call a method on `TTSPlayer` to generate and play the greeting with a ~2-second delay.
    - [ ] **4.3. TTS Generation:** (Handled within `TTSPlayer.kt` as per strategy in 4.2)
        - Use `android.speech.tts.TextToSpeech` API.
        - On initialization, set the language to Polish (e.g., `tts.setLanguage(new Locale("pl", "PL"))`).
        - Generate audio from the text string: "Cześć, tu Darek".
        - Use `tts.synthesizeToFile()` to save the generated speech as an audio file (e.g., `greeting_pl.wav`) in the app's cache directory (`context.cacheDir`).
    - [ ] **4.4. In-Call Playback:** (Handled within `TTSPlayer.kt` as per strategy in 4.2)
        - ~2 seconds after the call state becomes active (e.g., `Call.STATE_ACTIVE`), play the generated audio file (`greeting_pl.wav`). A `Handler().postDelayed(...)` or coroutine `delay()` can be used for the delay.
        - Use `android.media.MediaPlayer` to play the audio file.
        - **Crucially, configure `MediaPlayer` to play via the in-call audio stream: `mediaPlayer.setAudioAttributes(AudioAttributes.Builder().setLegacyStreamType(AudioManager.STREAM_VOICE_CALL).build())`.**
        - Before playing, request audio focus for `STREAM_VOICE_CALL` using `AudioManager.requestAudioFocus()`. For PoC, a transient focus request is likely sufficient. Ensure audio focus is abandoned after playback. (Note: The existing `InCallService` (`CallService.kt`) might already handle audio focus; investigate its interaction).
    - [ ] **4.5. Testing:**
        - Make an outgoing call to another phone.
        - Verify that ~2 seconds after the call connects, the "Cześć, tu Darek" audio is audible *on the other phone (far-end)*.
        - Confirm it doesn't just play out of the local device's speaker if the call is not on speakerphone.
    - [ ] **4.6. Build, Deploy & User Test:** Ask the user (Darek) to build the app, deploy it to a device, and manually test the TTS playback feature during a call, verifying against criteria in 4.5.

## General PoC Notes:
*   **Error Handling:** Basic error logging (Logcat) is sufficient. Robust user-facing error handling is not required.
*   **Code Structure:** Aim for understandable code, but extensive refactoring for architectural purity is not a PoC goal.
*   **Existing Codebase:** Leverage existing call management and UI components of the Dialer app (`CallService.kt`, `CallManager.kt`, `CallActivity.kt`) wherever possible. The PoC is about adding features, not rewriting the dialer. 