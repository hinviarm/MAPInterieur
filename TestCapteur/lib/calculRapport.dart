import 'dart:math';

import 'package:flutter/cupertino.dart';

double calculateScaleFactor(List<double> sideLengths, List<double> distancesFromPoint) {
  double cote = sqrt((distancesFromPoint[0]/sqrt(distancesFromPoint[1]))
      *(((pow(distancesFromPoint[2],2)/distancesFromPoint[0])*
          sqrt(distancesFromPoint[1]))+(pow(distancesFromPoint[1],2))));
  debugPrint('cote ============== '+ cote.toString());
  /*
  // Vérifie que les listes ont la taille appropriée
  if (sideLengths.length != 3 || distancesFromPoint.length != 3) {
    throw Exception("Both lists must contain exactly three elements.");
  }

double centreA = sqrt(2 * pow(sideLengths[1], 2) + 2 * pow(sideLengths[2], 2) - pow(sideLengths[0], 2)) / 3;

double centreB = sqrt(2 * pow(sideLengths[0], 2) + 2 * pow(sideLengths[2], 2) - pow(sideLengths[1], 2)) / 3;

double centreC = sqrt(2 * pow(sideLengths[0], 2) + 2 * pow(sideLengths[1], 2) - pow(sideLengths[2], 2)) / 3;

List<double> centre = [centreA,centreB,centreC];
  // Calcul des sommes des carrés des côtés et des distances
  double sumOfSideSquares = 0;
  double sumOfDistanceSquares = 0;
  for (int i = 0; i < 3; i++) {
    sumOfSideSquares += pow(centre[i], 2);
    sumOfDistanceSquares += pow(distancesFromPoint[i], 2);
  }

  // Calcul de k
  double k = sqrt(sumOfDistanceSquares / sumOfSideSquares);
   */
  return cote/sideLengths[0];
}
/*
void main() {
  // Exemple de côtés du triangle et distances au point P
  List<double> sides = [6, 4, 3];  // longueurs des côtés du triangle original
  List<double> distances = [5, 7, 16];  // distances du point P aux sommets

  // Calcul du facteur de proportionnalité k
  try {
    double scaleFactor = calculateScaleFactor(sides, distances);
    print("Le facteur de proportionnalité k est: $scaleFactor");
  } catch (e) {
    print("Erreur : ${e.toString()}");
  }
}
 */