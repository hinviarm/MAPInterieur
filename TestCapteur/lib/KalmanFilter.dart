class KalmanFilter {
  KalmanFilter(double processNoise, double sensorNoise, double estimatedError, double initialValue) {
    q = processNoise;
    r = sensorNoise;
    p = estimatedError;
    x = initialValue;

    print("Kalman Filter initialised");
  }

  /* Kalman filter variables */
  static const double TRAINING_PREDICTION_LIMIT = 500;
  double q = 0.0; //process noise covariance
  double r = 0.0; //measurement noise covariance
  double x = 0.0;//value
  double p = 0.0; //estimation error covariance
  double k = 0.0; //kalman gain
  double predictionCycles = 0;

  double getFilteredValue(double measurement) {
    // prediction phase
    p = p + q;

    // measurement update
    k = p / (p + r);
    x = x + k * (measurement - x);
    p = (1 - k) * p;

    return x;
  }
}