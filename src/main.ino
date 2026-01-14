#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <arduinoFFT.h>
#include <Arduino.h>


// ===============================
// CONFIGURACIÓN DE PINES
// ===============================
const int micPin = 35;      // Entrada del micrófono (MAX9814 OUT)
const int redPin = 26;      // PWM para canal Rojo
const int greenPin = 27;    // PWM para canal Verde  
const int bluePin = 33;     // PWM para canal Azul

// ===============================
// VARIABLES DE MODOS DE OPERACIÓN
// ===============================
bool musicMode = false;     // Modo reactivo a música
bool rainbowMode = false;   // Modo arcoíris automático
bool manualMode = true;     // Modo manual (activo por defecto)

// ===============================
// VARIABLES PARA MODO ARCOÍRIS
// ===============================
unsigned long lastColorChange = 0;
int rainbowHue = 0;
// Rainbow controls (ms between color steps, brightness multiplier 0.0-1.0)
unsigned long rainbowIntervalMs = 30; // default 30ms per step
float rainbowBrightness = 1.0; // 1.0 = 100%

// ===============================
// CONFIGURACIÓN FFT (ANÁLISIS DE AUDIO)
// ===============================
const int samples = 512;
const double samplingFrequency = 4000.0;
double vReal[samples];
double vImag[samples];
ArduinoFFT<double> FFT(vReal, vImag, samples, samplingFrequency);

// ===============================
// CONFIGURACIÓN PWM
// ===============================
const int pwmFreq = 5000;
const int pwmResolution = 8;
const int pwmMax = 255;
// PWM channels para ESP32 (LEDC)
const int redChannel = 0;
const int greenChannel = 1;
const int blueChannel = 2;


// ===============================
// CONFIGURACIÓN BLUETOOTH (BLE)
// ===============================
#define SERVICE_UUID        "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"
BLECharacteristic *pCharacteristic;

// ===============================
// VARIABLES PARA DETECCIÓN DE BEAT
// ===============================
// spectral flux based beat detection
double prevLowEnergy = 0; // kept for compatibility with older logic
double avgLowEnergy = 0;
const double smoothingFactor = 0.9;
// New spectral-flux variables
double prevMag[samples/2];
double avgFlux = 0.0;
const double fluxSmoothing = 0.85; // smoothing for the moving average of flux
float beatSensitivity = 1.6; // multiplier: flux > avgFlux * beatSensitivity -> beat
unsigned long lastBeatTime = 0;
const int beatHoldTime = 150; // ms
double beatThreshold = 400.0;

// ===============================
// CONFIG MUSIC SUBMODE + MULTICOLOR
// ===============================
int musicSubmode = 0; // 0 = monocolor, 1 = multicolor
unsigned long musicStepMs = 200; // ms per color step in multicolor mode
int musicHue = 0;
unsigned long lastMusicStepTime = 0;

// ===============================
// VARIABLES DE COLOR MANUAL
// ===============================
int redVal = 0, greenVal = 0, blueVal = 0;
// Color para modo música (color que parpadeará cuando se detecte beat)
int musicRed = 0, musicGreen = 0, musicBlue = 255; // default azul




// ===============================
// FUNCIONES BLE
// ===============================
std::vector<String> split(const String &str, char sep) {
  std::vector<String> tokens;
  int start = 0;
  int end = str.indexOf(sep);
  while (end != -1) {
    tokens.push_back(str.substring(start, end));
    start = end + 1;
    end = str.indexOf(sep, start);
  }
  tokens.push_back(str.substring(start));
  return tokens;
}

class MyCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      // Comando manual: RGB directo
      if (rxValue.length() == 3) {
        redVal = (uint8_t)rxValue[0];
        greenVal = (uint8_t)rxValue[1];
        blueVal = (uint8_t)rxValue[2];
        manualMode = true;
        musicMode = false;
        rainbowMode = false;
        applyColor(redVal, greenVal, blueVal);
      } else {
        String cmd = String(rxValue.c_str());
        if (cmd.startsWith("MUSIC")) {
          auto parts = split(cmd, ',');
          if (parts.size() == 4) {
            beatThreshold = parts[1].toInt();
            musicSubmode = parts[2].toInt();
            musicStepMs = parts[3].toInt();
            musicMode = true;
            manualMode = false;
            rainbowMode = false;
          }
        } else if (cmd.startsWith("RAINBOW")) {
          auto parts = split(cmd, ',');
          if (parts.size() == 3) {
            rainbowIntervalMs = parts[1].toInt();
            rainbowBrightness = parts[2].toInt() / 100.0f;
            rainbowMode = true;
            manualMode = false;
            musicMode = false;
          }
        } else if (cmd.startsWith("COLOR")) {
          auto parts = split(cmd, ',');
          if (parts.size() == 4) {
            redVal = parts[1].toInt();
            greenVal = parts[2].toInt();
            blueVal = parts[3].toInt();
            manualMode = true;
            musicMode = false;
            rainbowMode = false;
            applyColor(redVal, greenVal, blueVal);
          }
        }
      }
    }
  }
};

// ===============================
// APLICAR COLOR A LOS LEDs
// ===============================
void applyColor(int r, int g, int b) {
  ledcWrite(redChannel, r);
  ledcWrite(greenChannel, g);
  ledcWrite(blueChannel, b);
}

// ===============================
// DETECCIÓN DE BEAT Y REACCIÓN
// ===============================
void detectBeatAndReact() {
  static unsigned long lastSampleTime = 0;
  unsigned long now = micros();

  if (now - lastSampleTime < (1000000.0 / samplingFrequency)) return;
  lastSampleTime = now;

  // Lectura y procesamiento de muestras de audio (captura en vReal)
  double avg = 0;
  for (int i = 0; i < samples; i++) {
    vReal[i] = analogRead(micPin);
    avg += vReal[i];
    vImag[i] = 0;
    delayMicroseconds(50);
  }

  avg /= samples;
  for (int i = 0; i < samples; i++) {
    vReal[i] -= avg; // quitar DC
    // no clip here; let FFT handle small values
  }

  // Análisis FFT
  FFT.windowing(FFT_WIN_TYP_HAMMING, FFT_FORWARD);
  FFT.compute(FFT_FORWARD);
  FFT.complexToMagnitude(); // ahora vReal contiene magnitudes

  // Spectral flux: suma de aumentos positivos entre frames en banda baja
  double flux = 0.0;
  int lowBin = 2; // bin 2 ~ (2 * fs / N)
  int highBin = samples / 8; // limitarnos a bajas-medias frecuencias
  if (highBin >= samples/2) highBin = samples/2 - 1;

  for (int i = lowBin; i <= highBin; i++) {
    double mag = vReal[i];
    double diff = mag - prevMag[i];
    if (diff > 0) flux += diff;
    prevMag[i] = mag;
  }

  // Mantenemos promedio suavizado de flux
  avgFlux = fluxSmoothing * avgFlux + (1.0 - fluxSmoothing) * flux;

  // Detectar beat usando umbral adaptativo basado en avgFlux
  bool beatDetected = false;
  if (avgFlux > 0.0 && flux > (avgFlux * beatSensitivity) && (millis() - lastBeatTime > beatHoldTime)) {
    beatDetected = true;
    lastBeatTime = millis();
    // Aplicar color seleccionado para modo música
    int rv = constrain(musicRed, 0, pwmMax);
    int gv = constrain(musicGreen, 0, pwmMax);
    int bv = constrain(musicBlue, 0, pwmMax);
    ledcWrite(redChannel, rv);
    ledcWrite(greenChannel, gv);
    ledcWrite(blueChannel, bv);
  }

  // Reacción al beat (color elegido) o desvanecimiento
  if (beatDetected) {
    // already wrote the chosen music color above
  } else {
    // desvanecimiento suave basado en tiempo desde el último beat
    int fade = map(millis() - lastBeatTime, 0, beatHoldTime, 255, 0);
    fade = constrain(fade, 0, 255);
    // desvanecer desde el color de música hacia apagado
    float f = fade / 255.0;
    int rv = (int)constrain(musicRed * f, 0, pwmMax);
    int gv = (int)constrain(musicGreen * f, 0, pwmMax);
    int bv = (int)constrain(musicBlue * f, 0, pwmMax);
    ledcWrite(redChannel, rv);
    ledcWrite(greenChannel, gv);
    ledcWrite(blueChannel, bv);
  }
}

// ===============================
// APLICAR COLOR ARCOÍRIS (HSV to RGB)
// ===============================
void applyRainbowColor(int hue) {
  float r, g, b;
  // Conversión simple HSV a RGB
  int region = hue / 60;
  float f = (hue / 60.0) - region;
  float q = 1 - f;

  switch(region) {
    case 0: r=1; g=f; b=0; break;
    case 1: r=q; g=1; b=0; break;
    case 2: r=0; g=1; b=f; break;
    case 3: r=0; g=q; b=1; break;
    case 4: r=f; g=0; b=1; break;
    default: r=1; g=0; b=q; break;
  }

  // Escribir en los canales LEDC (rojo, verde, azul)
  int rv = (int)(r * 255 * rainbowBrightness);
  int gv = (int)(g * 255 * rainbowBrightness);
  int bv = (int)(b * 255 * rainbowBrightness);
  rv = constrain(rv, 0, pwmMax);
  gv = constrain(gv, 0, pwmMax);
  bv = constrain(bv, 0, pwmMax);
  ledcWrite(redChannel, rv);
  ledcWrite(greenChannel, gv);
  ledcWrite(blueChannel, bv);
}

// Helper: convert HSV hue (0-359) to RGB ints (0-255)
void hsvHueToRgbInt(int hue, int &outR, int &outG, int &outB, float brightness=1.0f) {
  float r,g,b;
  int region = hue / 60;
  float f = (hue / 60.0) - region;
  float q = 1 - f;
  switch(region) {
    case 0: r=1; g=f; b=0; break;
    case 1: r=q; g=1; b=0; break;
    case 2: r=0; g=1; b=f; break;
    case 3: r=0; g=q; b=1; break;
    case 4: r=f; g=0; b=1; break;
    default: r=1; g=0; b=q; break;
  }
  outR = (int)constrain(r * 255.0 * brightness, 0, pwmMax);
  outG = (int)constrain(g * 255.0 * brightness, 0, pwmMax);
  outB = (int)constrain(b * 255.0 * brightness, 0, pwmMax);
}

// ===============================
// CONFIGURACIÓN INICIAL
// ===============================

  BLEDevice::init("Music-Led-2.0");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pCharacteristic->setCallbacks(new MyCallbacks());
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->start();
  Serial.println("Esperando conexión Bluetooth...");
}

// ===============================
// LOOP PRINCIPAL
// ===============================
void loop() {
  if (musicMode) {
    unsigned long currentMillis = millis();
    if (musicSubmode == 1) {
      if (currentMillis - lastMusicStepTime > musicStepMs) {
        lastMusicStepTime = currentMillis;
        musicHue = (musicHue + 1) % 360;
        int r,g,b;
        hsvHueToRgbInt(musicHue, r, g, b, rainbowBrightness);
        musicRed = r; musicGreen = g; musicBlue = b;
      }
    }
    detectBeatAndReact();
  }
  else if (rainbowMode) {
    unsigned long currentMillis = millis();
    if (currentMillis - lastColorChange > rainbowIntervalMs) {
      rainbowHue = (rainbowHue + 1) % 360;
      applyRainbowColor(rainbowHue);
      lastColorChange = currentMillis;
    }
  }
  else if (manualMode) {
    applyColor(redVal, greenVal, blueVal);
  }
  delay(5);
}