function eps = indgrebsgrad(m, n1, n2, alpha_deg)
% Antagelser:
% - Lige fortanding (spur gears)
% - Standard addendum: ha = m
% - Standard centerafstand: a = r1 + r2 (ingen profilforskydning)

  arguments
    m double {mustBeNumeric}
    n1 double {mustBeNumeric}
    n2 double {mustBeNumeric}
    alpha_deg double {mustBeNumeric} = 20
  end

  alpha = deg2rad(alpha_deg);

  %delecirkeldiametre
  d1 = m * n1;
  d2 = m * n2;

  %centerafstand
  a = d1/2 + d2/2;

  %grundcirkeldiametre
  db1 = d1 * cos(alpha);
  db2 = d2 * cos(alpha);

  %tandtopdiametre
  da1 = d1 + 2 * m;
  da2 = d2 + 2 * m;

  % Geometri-check: ra must be >= rb
  if da1 < db1 || da2 < db2
      error("Ugyldig geometri: addendumcirkel < basecirkel (tjek alpha, m, z).");
  end

  %indgrebslængde
  L = 0.5 * (sqrt(da1^2 - db1^2) + sqrt(da2^2 - db2^2)) - a * sin(alpha);

  %evolventafstand
  e = m * pi * cos(alpha);

  eps = L/e;

  if eps <= 0
    warning("Indgrebsgrad blev <= 0. Tjek om antagelserne (standard a, ha) passer til opgaven.");
  end
end