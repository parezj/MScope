<div align="center" margin="0" padding="0">
<img src="https://raw.githubusercontent.com/parezj/MScope/master/img/logo.png" alt="MScope" width="200" height="200">
</div>

# MScope - MATLAB Sound card Oscilloscope
> Run this app with start.m or download Windows executable from **[HERE](https://github.com/parezj/MScope/releases)**  

1. [Modes](#1-Modes)
2. [Settings](#2-Settings)
3. [Class Diagram](#3-Class-Diagram)
4. [Screenshots](#4-Screenshots)

## 1. Modes
- **Audio Recorder**
  - free solution
  - not good for long recordings, memory is cummulated 
- **Audio Device Reader**
  - paid Audio Toolbox required, if running from MATLAB
  - recommended, memory is managed very well
- **Simulation**
  - simple timer based software function generation
  
## 2. Settings
When using audio recording, you need to enter correct Vmax value. This is the max voltage input level,
equivalent to highest bit value, when signal is not saturated. You can look it up in your soundcard specs,
for example mine (*RME Babyface Pro*) has this written in technical reference:  
  
Maximum input level @+4 dBu, Gain 0 dB: **+13 dBu**  
  
You are concerned about the last value, +13 dBu, which you need to convert from decibel units to volts,
for instance with this [lookup chart](http://www.cranesong.com/Volts%20to%20dBu%20to%20VU%20Comparison.pdf)

## 3. Class Diagram
![Download](https://raw.githubusercontent.com/parezj/MScope/master/img/ClassDiagram.png)

## 4. Screenshots
- **Sine 1123 Hz - signal**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/sine_1123_sig.png)
  
- **Sine 1123 Hz - FFT**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/sine_1123_fft.png)
  
- **Sine 1123 Hz - FFT zoomed**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/sine_1123_fft2.png)
  
- **Square 1123 Hz - signal**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/square_1123_sig.png)
  
- **Square 1123 Hz - signal 2**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/square_1123_sig2.png)
  
- **Square 1123 Hz - FFT**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/square_1123_fft2.png)
  
- **Triangle 1123 Hz - signal**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/triangle_1123_sig.png)
  
- **Triangle 1123 Hz - FFT**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/triangle_1123_fft.png)

- **Sine 20273 Hz - signal**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/sine_20273.png)

- **Sine 20273 Hz - FFT**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/sine_20273_fft.png)

- **Signal source - ancient DIY analog function generator**:  
![Download](https://raw.githubusercontent.com/parezj/MScope/master/screenshots/ancient_dyi_generator.png)