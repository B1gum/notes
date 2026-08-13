%% TITLE AND PURPOSE
% A1 - Cirkulaer aksel med kendte boejningsmomenter, torsion og aksialkraft
%
% Brug dette script naar:
% - et kritisk tvaersnit i en massiv eller hul cirkulaer aksel er kendt;
% - My, Mz, torsionsmoment T og eventuel aksialkraft N er kendte;
% - der spoerges efter spaendinger og sikkerhed mod flydning.
%
% Brug ikke dette script naar:
% - lejekraefter, reaktioner eller momentdiagrammer foerst skal bestemmes
%   (brug i stedet A2);
% - der skal udføres udmattelsesberegning/Haigh-diagram (brug A3);
% - tvaersnittet ikke er cirkulaert.
%
% Det skal bestemmes manuelt foer brug:
% - det kritiske tvaersnit og de tilhoerende snitkraefter;
% - eventuelle spaendingskoncentrationsfaktorer fra kursusfigur/tabel;
% - materialets flydespaending og det kraevede sikkerhedsniveau.

clear; clc; close all;

%% ASSUMPTIONS AND MANUAL INPUT
% Enhedssystem: N, mm og MPa (= N/mm^2).
% Momenter indtastes i N*m og konverteres eksplicit til N*mm.
%
% Fortegn:
% - axialForce_N > 0 betyder traek, < 0 betyder tryk.
% - fortegnene paa My, Mz og T bevares som dokumentation, men
%   von Mises-resultatet afhaenger af deres stoerrelser.
%
% Tvaersnittet antages at vaere cirkulaert og linearelastisk.
% Bøjningsspaendingen vurderes i de to modstaaende yderfibre:
%   Fiber A: lokal aksialspaending + lokal maksimal boejningsspaending
%   Fiber B: lokal aksialspaending - lokal maksimal boejningsspaending
%
% Kt-faktorerne antages at vaere teoretiske lokale faktorer, som endnu
% ikke er inkluderet i de indtastede momenter eller nominelle spaendinger.
% Saet dem til 1.0, hvis der ikke er en relevant kaerv/notch/skulder.

%% INPUT
outerDiameter_mm = 30;        % [mm] Ydre akseldiameter D
innerDiameter_mm = 0;         % [mm] Indre diameter d; 0 for massiv aksel

bendingMomentY_Nm = -62;      % [N*m] Boejningsmoment My i kritisk snit
bendingMomentZ_Nm = -78;      % [N*m] Boejningsmoment Mz i kritisk snit
torque_Nm = 26;               % [N*m] Torsionsmoment T i kritisk snit
axialForce_N = 0;             % [N] Aksialkraft N; positiv i traek

yieldStrength_MPa = 240;      % [MPa] Materialets flydespaending
requiredSafetyFactor = 1.00;  % [-] Kraevet sikkerhed mod flydning

Kt_bending = 1.00;            % [-] Spaendingskoncentration for boejning
Kt_torsion = 1.00;            % [-] Spaendingskoncentration for torsion
Kt_axial = 1.00;              % [-] Spaendingskoncentration for aksiallast

runCourseTests = true;        % [logisk] Koer indbyggede kursuskontroller

%% UNIT CHECK AND VALIDATION
scalarInputs = [outerDiameter_mm, innerDiameter_mm, ...
    bendingMomentY_Nm, bendingMomentZ_Nm, torque_Nm, axialForce_N, ...
    yieldStrength_MPa, requiredSafetyFactor, ...
    Kt_bending, Kt_torsion, Kt_axial];

assert(all(isfinite(scalarInputs)), ...
    'Alle numeriske input skal vaere endelige tal.');
assert(outerDiameter_mm > 0, ...
    'Ydre diameter skal vaere stoerre end 0 mm.');
assert(innerDiameter_mm >= 0, ...
    'Indre diameter maa ikke vaere negativ.');
assert(innerDiameter_mm < outerDiameter_mm, ...
    'Indre diameter skal vaere mindre end ydre diameter.');
assert(yieldStrength_MPa > 0, ...
    'Flydespaendingen skal vaere stoerre end 0 MPa.');
assert(requiredSafetyFactor > 0, ...
    'Kraevet sikkerhedsfaktor skal vaere stoerre end 0.');
assert(all([Kt_bending, Kt_torsion, Kt_axial] >= 1), ...
    'Kt-faktorer for denne statiske lokale kontrol skal vaere >= 1.');
assert(islogical(runCourseTests) && isscalar(runCourseTests), ...
    'runCourseTests skal vaere true eller false.');

if innerDiameter_mm / outerDiameter_mm > 0.90
    warning(['Tvaersnittet er meget tyndvaegget. Formlerne er geometrisk ', ...
        'gyldige, men kontroller lokale effekter og valgt model.']);
end

%% CALCULATION
% Geometri for massiv eller hul cirkulaer aksel
outerRadius_mm = outerDiameter_mm / 2;

crossSectionArea_mm2 = pi/4 * ...
    (outerDiameter_mm^2 - innerDiameter_mm^2);

secondMomentArea_mm4 = pi/64 * ...
    (outerDiameter_mm^4 - innerDiameter_mm^4);

polarMomentArea_mm4 = pi/32 * ...
    (outerDiameter_mm^4 - innerDiameter_mm^4);

sectionModulusBending_mm3 = secondMomentArea_mm4 / outerRadius_mm;
sectionModulusTorsion_mm3 = polarMomentArea_mm4 / outerRadius_mm;

% Eksplicit enhedskonvertering: N*m -> N*mm
bendingMomentY_Nmm = bendingMomentY_Nm * 1e3;
bendingMomentZ_Nmm = bendingMomentZ_Nm * 1e3;
torque_Nmm = torque_Nm * 1e3;

% Resulterende boejningsmoment
bendingMomentResultant_Nmm = hypot( ...
    bendingMomentY_Nmm, bendingMomentZ_Nmm);
bendingMomentResultant_Nm = bendingMomentResultant_Nmm / 1e3;

% Nominelle spaendinger
sigmaAxialNominal_MPa = axialForce_N / crossSectionArea_mm2;

sigmaBendingNominalMax_MPa = ...
    bendingMomentResultant_Nmm / sectionModulusBending_mm3;

tauTorsionNominalMax_MPa = ...
    abs(torque_Nmm) / sectionModulusTorsion_mm3;

% Lokale spaendinger efter de indtastede Kt-faktorer
sigmaAxialLocal_MPa = Kt_axial * sigmaAxialNominal_MPa;

sigmaBendingLocalMax_MPa = ...
    Kt_bending * sigmaBendingNominalMax_MPa;

tauTorsionLocalMax_MPa = ...
    Kt_torsion * tauTorsionNominalMax_MPa;

% De to modstaaende yderfibre
sigmaNormalFiberA_MPa = ...
    sigmaAxialLocal_MPa + sigmaBendingLocalMax_MPa;

sigmaNormalFiberB_MPa = ...
    sigmaAxialLocal_MPa - sigmaBendingLocalMax_MPa;

% von Mises for plan spaending med normalspaending og torsionsspaending
sigmaVonMisesFiberA_MPa = sqrt( ...
    sigmaNormalFiberA_MPa^2 + 3*tauTorsionLocalMax_MPa^2);

sigmaVonMisesFiberB_MPa = sqrt( ...
    sigmaNormalFiberB_MPa^2 + 3*tauTorsionLocalMax_MPa^2);

if sigmaVonMisesFiberA_MPa >= sigmaVonMisesFiberB_MPa
    sigmaVonMisesMax_MPa = sigmaVonMisesFiberA_MPa;
    criticalNormalStress_MPa = sigmaNormalFiberA_MPa;
    criticalFiber = "Fiber A";
else
    sigmaVonMisesMax_MPa = sigmaVonMisesFiberB_MPa;
    criticalNormalStress_MPa = sigmaNormalFiberB_MPa;
    criticalFiber = "Fiber B";
end

if sigmaVonMisesMax_MPa > 0
    yieldSafetyFactor = yieldStrength_MPa / sigmaVonMisesMax_MPa;
else
    yieldSafetyFactor = Inf;
end

%% RESULTS
fprintf('\n===== A1: CIRKULAER AKSEL, KENDTE MOMENTER =====\n');

fprintf('Tvaersnit: D = %.3f mm, d = %.3f mm\n', ...
    outerDiameter_mm, innerDiameter_mm);

fprintf('Areal A:                         %.3f mm^2\n', ...
    crossSectionArea_mm2);

fprintf('Boejningsmodstandsmoment Wb:     %.3f mm^3\n', ...
    sectionModulusBending_mm3);

fprintf('Torsionsmodstandsmoment Wt:      %.3f mm^3\n', ...
    sectionModulusTorsion_mm3);

fprintf('Resulterende boejningsmoment:    %.3f N*m\n', ...
    bendingMomentResultant_Nm);

fprintf('\n');

fprintf('Nominel aksialspaending:          %+.3f MPa\n', ...
    sigmaAxialNominal_MPa);

fprintf('Maks. nominel boejningsspaending: %.3f MPa\n', ...
    sigmaBendingNominalMax_MPa);

fprintf('Maks. nominel torsionsspaending:  %.3f MPa\n', ...
    tauTorsionNominalMax_MPa);

fprintf('\n');

fprintf('Lokal normalspaending, fiber A:   %+.3f MPa\n', ...
    sigmaNormalFiberA_MPa);

fprintf('Lokal normalspaending, fiber B:   %+.3f MPa\n', ...
    sigmaNormalFiberB_MPa);

fprintf('Lokal torsionsspaending:          %.3f MPa\n', ...
    tauTorsionLocalMax_MPa);

fprintf('Kritisk yderfiber:                %s\n', criticalFiber);

fprintf('Maksimal von Mises-spaending:     %.3f MPa\n', ...
    sigmaVonMisesMax_MPa);

fprintf('Sikkerhedsfaktor mod flydning:    %.3f\n', ...
    yieldSafetyFactor);

results = struct;

results.crossSectionArea_mm2 = crossSectionArea_mm2;
results.secondMomentArea_mm4 = secondMomentArea_mm4;
results.polarMomentArea_mm4 = polarMomentArea_mm4;

results.sectionModulusBending_mm3 = ...
    sectionModulusBending_mm3;

results.sectionModulusTorsion_mm3 = ...
    sectionModulusTorsion_mm3;

results.bendingMomentResultant_Nm = ...
    bendingMomentResultant_Nm;

results.sigmaAxialNominal_MPa = ...
    sigmaAxialNominal_MPa;

results.sigmaBendingNominalMax_MPa = ...
    sigmaBendingNominalMax_MPa;

results.tauTorsionNominalMax_MPa = ...
    tauTorsionNominalMax_MPa;

results.sigmaNormalFiberA_MPa = ...
    sigmaNormalFiberA_MPa;

results.sigmaNormalFiberB_MPa = ...
    sigmaNormalFiberB_MPa;

results.tauTorsionLocalMax_MPa = ...
    tauTorsionLocalMax_MPa;

results.criticalFiber = criticalFiber;

results.criticalNormalStress_MPa = ...
    criticalNormalStress_MPa;

results.sigmaVonMisesMax_MPa = ...
    sigmaVonMisesMax_MPa;

results.yieldSafetyFactor = yieldSafetyFactor;
results.requiredSafetyFactor = requiredSafetyFactor;

%% AUTOMATIC CHECKS
if yieldSafetyFactor >= requiredSafetyFactor
    statusText = "OK";

    fprintf(['\nOK: Sikkerhedsfaktoren %.3f er stoerre end eller lig ', ...
        'det kraevede niveau %.3f.\n'], ...
        yieldSafetyFactor, requiredSafetyFactor);
else
    statusText = "IKKE OK";

    fprintf(['\nIKKE OK: Sikkerhedsfaktoren %.3f er mindre end ', ...
        'det kraevede niveau %.3f. Akslen risikerer lokal flydning.\n'], ...
        yieldSafetyFactor, requiredSafetyFactor);
end

if sigmaVonMisesMax_MPa > yieldStrength_MPa
    fprintf(['IKKE OK: von Mises-spaendingen %.3f MPa overstiger ', ...
        'flydespaendingen %.3f MPa.\n'], ...
        sigmaVonMisesMax_MPa, yieldStrength_MPa);

elseif sigmaVonMisesMax_MPa == 0
    fprintf('ADVARSEL: Alle indtastede laster er nul.\n');

else
    fprintf(['OK: von Mises-spaendingen %.3f MPa er under ', ...
        'flydespaendingen %.3f MPa.\n'], ...
        sigmaVonMisesMax_MPa, yieldStrength_MPa);
end

results.status = statusText;

%% PLOTS
% A1 analyserer ét allerede identificeret kritisk tvaersnit.
% Der tilfoejes derfor ikke et standardplot.
%
% Hvis momentdiagrammer eller variation langs akslen skal vises,
% er opgaven en A2-opgave.

%% PHYSICAL CONCLUSION
fprintf('\n===== FYSISK KONKLUSION =====\n');

if yieldSafetyFactor >= requiredSafetyFactor
    fprintf(['Det undersoegte tvaersnit opfylder det valgte statiske ', ...
        'flydekriterium med sikkerhedsfaktor %.3f.\n'], ...
        yieldSafetyFactor);
else
    fprintf(['Det undersoegte tvaersnit opfylder ikke det valgte ', ...
        'statiske flydekriterium; geometri, materiale eller last skal ', ...
        'aendres.\n']);
end

fprintf(['Konklusionen gaelder kun for det valgte snit og de indtastede ', ...
    'snitkraefter/Kt-faktorer. Reaktioner, momentdiagrammer, katalogopslag ', ...
    'og udmattelse er ikke kontrolleret her.\n']);

%% OPTIONAL TEST CASES
% Testene er regressionstests mod afrundede resultater i kursusmaterialet.
% De erstatter ikke en MATLAB-kørsel på brugerens egen installation.

if runCourseTests
    fprintf('\n===== KURSUSKONTROLLER =====\n');

    % Test 1: Eksempel-eksamen, problem 4
    % D = 30 mm, My = -62 N*m, Mz = -78 N*m, T = 26 N*m.
    % Kursusresultat: sigma_vm = 38.5 MPa og n = 6.23.
    testD_mm = 30;

    testWb_mm3 = pi*testD_mm^3/32;
    testWt_mm3 = pi*testD_mm^3/16;

    testMres_Nmm = hypot(-62, -78)*1e3;

    testSigmaB_MPa = testMres_Nmm/testWb_mm3;
    testTau_MPa = abs(26e3)/testWt_mm3;

    testVmExam_MPa = sqrt( ...
        testSigmaB_MPa^2 + 3*testTau_MPa^2);

    testSafetyExam = 240/testVmExam_MPa;

    % Test 2: Akseloevelse ved x = 0.1 m og x = 0.9 m.
    % Kursusmaterialet angiver nominelt sigma_b = 200 MPa,
    % tau = 29.5 MPa, Kt,b = 1.35 og Kt,t = 1.20.
    testVmShoulder_MPa = sqrt( ...
        (1.35*200)^2 + 3*(1.20*29.5)^2);

    % Test 3: Akseloevelse ved x = 0.6 m.
    % Kursusmaterialet angiver nominelt sigma_b = 53 MPa,
    % tau = 6.4 MPa, Kt,b = 1.55 og Kt,t = 1.35.
    testVmGearSeat_MPa = sqrt( ...
        (1.55*53)^2 + 3*(1.35*6.4)^2);

    testName = [ ...
        "Eksamen problem 4: sigma_vm"; ...
        "Akseloevelse x=0.1/0.9 m"; ...
        "Akseloevelse x=0.6 m"; ...
        "Eksamen problem 4: sikkerhed"];

    calculatedValue = [ ...
        testVmExam_MPa; ...
        testVmShoulder_MPa; ...
        testVmGearSeat_MPa; ...
        testSafetyExam];

    courseValue = [38.5; 277; 83; 6.23];
    tolerance = [0.10; 1.0; 1.0; 0.01];

    passed = ...
        abs(calculatedValue - courseValue) <= tolerance;

    testResults = table( ...
        testName, calculatedValue, courseValue, tolerance, passed);

    disp(testResults);

    assert(all(passed), ...
        'Mindst én kursuskontrol afviger mere end den valgte tolerance.');

    fprintf(['OK: Alle kursuskontroller ligger inden for tolerancen. ', ...
        'Små forskelle skyldes afrunding i slides/loesningsforslag.\n']);
end