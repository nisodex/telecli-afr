import 'dart:math' as math;

/// RF calculation utilities for 5G Fixed Wireless Access (AFR 5G) installations.
class RfCalculator {
  // Speed of light in m/s
  static const double speedOfLight = 299792458.0;

  // Standard frequencies in MHz for Movistar bands
  static const double freq5Gn78Mhz = 3500.0;
  static const double freq5Gn28Mhz = 700.0;
  static const double freq4GlteMhz = 1800.0;

  // Typical Movistar BTS Transmission parameters
  static const double txPowerN78Dbm = 62.0; // Macro gNodeB EIRP 3.5 GHz
  static const double txPowerN28Dbm = 58.0; // Macro gNodeB EIRP 700 MHz

  // Default CPE Antenna Gain (ODU outdoor unit)
  static const double defaultCpeGainN78Dbi = 11.5;
  static const double defaultCpeGainN28Dbi = 8.0;
  static const double defaultCableLossDb = 0.5;

  /// Calculates Free Space Path Loss (FSPL) in decibels.
  /// Formula: FSPL(dB) = 20*log10(d_m) + 20*log10(f_MHz) - 27.55
  static double calculateFspl(double distanceMeters, double frequencyMhz) {
    if (distanceMeters <= 0 || frequencyMhz <= 0) return 0.0;
    final double logD = math.log(distanceMeters) / math.ln10;
    final double logF = math.log(frequencyMhz) / math.ln10;
    return 20.0 * logD + 20.0 * logF - 27.55;
  }

  /// Calculates the 1st Fresnel zone radius in meters at the midpoint of the link.
  /// Formula: r1 = sqrt( (c * d) / (4 * f) ) = sqrt( (75 * d_m) / f_MHz )
  static double calculateFresnelRadius(double distanceMeters, double frequencyMhz) {
    if (distanceMeters <= 0 || frequencyMhz <= 0) return 0.0;
    final double radius = math.sqrt((75.0 * distanceMeters) / frequencyMhz);
    return radius;
  }

  /// Calculates the recommended 60% clearance radius for the 1st Fresnel zone.
  static double calculateFresnel60PercentClearance(double distanceMeters, double frequencyMhz) {
    return calculateFresnelRadius(distanceMeters, frequencyMhz) * 0.6;
  }

  /// Estimates the received RSRP (in dBm) for a given distance and frequency band.
  static double estimateRsrp({
    required double distanceMeters,
    required bool isN78,
    double? customAntennaGainDbi,
    double cableLossDb = defaultCableLossDb,
  }) {
    final double freq = isN78 ? freq5Gn78Mhz : freq5Gn28Mhz;
    final double txEirp = isN78 ? txPowerN78Dbm : txPowerN28Dbm;
    final double rxGain = customAntennaGainDbi ?? (isN78 ? defaultCpeGainN78Dbi : defaultCpeGainN28Dbi);

    final double fspl = calculateFspl(distanceMeters, freq);

    // In 3GPP 5G NR, RSRP is measured per resource element (RE).
    // Total carrier EIRP is spread over 3276 subcarriers (100 MHz n78) or 624 subcarriers (20 MHz n28).
    // Channel subcarrier spread offset:
    // - 100 MHz: 10 * log10(3276) ≈ 35.2 dB
    // - 20 MHz: 10 * log10(624) ≈ 28.0 dB
    final double ssbSubcarrierSpread = isN78 ? 35.2 : 28.0;

    // Environmental clutter / log-normal fading margin (typical outdoor rooftop)
    const double environmentalMarginDb = 5.0;

    final double rsrp = txEirp - fspl + rxGain - cableLossDb - ssbSubcarrierSpread - environmentalMarginDb;
    return rsrp.clamp(-140.0, -45.0);
  }

  /// Checks if the antenna orientation is within the Half Power Beamwidth (HPBW) main lobe.
  static bool isInsideMainBeam({
    required double angularDeviation,
    required bool isN78,
  }) {
    final double maxHpbw = isN78 ? 15.0 : 35.0; // 3.5 GHz is narrower and more directive
    return angularDeviation.abs() <= maxHpbw;
  }

  /// Returns signal quality tier based on RSRP dBm.
  static SignalQualityTier evaluateSignalQuality(double rsrpDbm) {
    if (rsrpDbm >= -80.0) {
      return SignalQualityTier.excellent;
    } else if (rsrpDbm >= -92.0) {
      return SignalQualityTier.good;
    } else if (rsrpDbm >= -105.0) {
      return SignalQualityTier.fair;
    } else {
      return SignalQualityTier.poor;
    }
  }

  /// Estimates the theoretical downlink throughput in Mbps based on RSRP and technology.
  static int estimateDownlinkThroughput({
    required double rsrpDbm,
    required bool isN78,
  }) {
    if (isN78) {
      // 5G n78 (100 MHz channel)
      if (rsrpDbm >= -80.0) return 950;
      if (rsrpDbm >= -88.0) return 650;
      if (rsrpDbm >= -95.0) return 380;
      if (rsrpDbm >= -105.0) return 150;
      return 45;
    } else {
      // 5G n28 (20 MHz channel)
      if (rsrpDbm >= -80.0) return 180;
      if (rsrpDbm >= -88.0) return 120;
      if (rsrpDbm >= -95.0) return 75;
      if (rsrpDbm >= -105.0) return 35;
      return 12;
    }
  }

  /// Calculates the local magnetic declination approximation for Spain (in degrees).
  /// Spain peninsular declination is roughly between -1.5° (West) in Galicia and +0.5° (East) in Catalonia.
  static double estimateMagneticDeclination(double lat, double lon) {
    // Linear approximation model for mainland Spain: WMM epoch 2025-2026
    // Center at Madrid (40.4°N, -3.7°W) is approximately -0.5°
    final double declination = -0.5 + (lon + 3.7) * 0.28 + (lat - 40.4) * 0.05;
    return declination;
  }
}

enum SignalQualityTier {
  excellent, // RSRP >= -80 dBm
  good,      // -80 to -92 dBm
  fair,      // -92 to -105 dBm
  poor,      // < -105 dBm
}
