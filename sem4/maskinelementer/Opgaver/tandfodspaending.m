function [sigma_MPa, out] = tandfodspaending(Wt, b_mm, m_mm, mc, N, d_m, omega, Qv)
  arguments
    Wt    (1,1) double {mustBePositive}
    b_mm  (1,1) double {mustBePositive}
    m_mm  (1,1) double {mustBePositive}
    mc    (1,1) double {mustBePositive}
    N     (1,1) double {mustBePositive}
    d_m   (1,1) double {mustBePositive}
    omega (1,1) double {mustBePositive}
    Qv    (1,1) double {mustBePositive}
  end

  % --- Lewis formfaktor
  Ke = 1/mc;
  Kf = 2.2 + 3.1*exp(-N/14);
  Y  = 1/(Ke*Kf);

  % --- Dynamisk faktor
  V = (d_m/2) * omega;
  B = 0.25 * (12 - Qv)^(2/3);
  A = 50 + 56*(1 - B);
  Kv = ((A + sqrt(200*V))/A)^B;

  % --- Tandfodsspænding
  sigma_MPa = Kv * Wt / (b_mm * m_mm * Y);

  % Potentielt debug output
  out.Ke = Ke; out.Kf = Kf; out.Y = Y;
  out.V  = V;  out.A  = A;  out.B = B; out.Kv = Kv;
end