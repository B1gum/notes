%% B3 - TILSPAENDINGSMOMENT OG FRIKTIONSBIDRAG
% Brug dette script naar:
%   - en kendt forspaendingskraft F_i skal omsaettes til tilspaendingsmoment,
%   - en maalt/angivet momentvaerdi skal omsaettes til forspaendingskraft,
%   - gevind-, anlaegs- og nyttemoment skal adskilles,
%   - maksimal momentvaerdi ved proof load skal bestemmes,
%   - von Mises-spaendingen under selve tilspaendingen skal kontrolleres.
%
% Brug ikke dette script naar:
%   - bolt- og emnestivhed, separation eller ydre last er hovedproblemet
%     (brug B1/B2),
%   - spindlen bruges til kontinuerlig kraftoverfoersel (brug B4),
%   - friktionskoefficienter eller kontaktgeometri er ukendte og en
%     praecis forspaending derfor ikke kan forventes.
%
% Kursusgrundlag:
%   T = F_i*d_m/2 * ((tan(lambda)+f*sec(alpha)) / ...
%       (1-f*tan(lambda)*sec(alpha))) + F_i*f_c*d_c/2
%   tan(lambda) = lead/(pi*d_m)
%   d_m = (nominel diameter + minor diameter)/2
%   d_c = (ydre anlaegsdiameter + indre anlaegsdiameter)/2
%   T = K*F_i*d, ligning (8-27)
%   Ved f=f_c=0.15 anvendes ofte K=0.20 i kursusopgaverne.
%
% Scriptets standardcase svarer til kursusopgave 8-b:
%   M14x2, A_t=115 mm^2, S_p=380 MPa, permanent samling.
%   Den valgte designmodel er K=0.20 for at reproducere facit.
%   Den detaljerede friktionsmodel beregnes samtidig til sammenligning.

clear; clc; close all;

%% ASSUMPTIONS AND MANUAL INPUT
% Enheder internt: N, mm og MPa (= N/mm^2).
% Indtastede momenter er i N*m og omregnes eksplicit til N*mm.
% Gevindet antages hoejrehaandet og tilspaendingen svarer til "loeft".
% Friktionskoefficienterne antages konstante under tilspaendingen.
% Kursusmodellen bruger alpha=30 deg for metrisk 60-deg gevind.
% Ved von Mises-kontrollen bruger kursusopgave 8-b3 det samlede
% tilspaendingsmoment og nomineldiameteren i W_p=pi*d^3/16.
% A_t, minorareal/-diameter, S_p og reelle anlaegsdiametre er opslag.
% K=0.20 er en kursusapproksimation, ikke en universel materialekonstant.

%% INPUT
% --- Beregningsretning og valgt designmodel ---
analysisMode = "preloadToTorque";    % [-] "preloadToTorque" eller "torqueToPreload"
selectedTorqueModel = "nutFactor";   % [-] "nutFactor" eller "exactCourse"

% --- Kraft eller moment ---
preloadForceInput = 39.33e3;         % [N] Kendt forspaendingskraft F_i
tighteningTorqueInput = 110.124;     % [N*m] Kendt tilspaendingsmoment T

% --- Gevindgeometri ---
nominalDiameter = 14;                % [mm] Nominel boltdiameter d
threadPitch = 2;                     % [mm] Gevindstigning p
numberOfThreadStarts = 1;            % [-] Antal gevindstarter
threadHalfAngleDeg = 30;             % [deg] alpha, 30 deg for metrisk gevind

threadMeanDiameterMode = "fromMinorArea"; % [-] "fromMinorArea", "fromMinorDiameter" eller "manual"
minorArea = 104;                     % [mm^2] Minorareal A_r, kursustabel 8-1
minorDiameterManual = NaN;           % [mm] Manuel minor diameter
threadMeanDiameterManual = NaN;      % [mm] Manuel middeldiameter d_m

% --- Anlaegsflade under moetrik/bolthoved ---
bearingMeanDiameterMode = "fromDiameters"; % [-] "fromDiameters" eller "manual"
bearingOuterDiameter = 21;           % [mm] Ydre anlaegsdiameter A; her 1.5*d
bearingInnerDiameter = 14;           % [mm] Indre anlaegsdiameter B; her d
bearingMeanDiameterManual = NaN;     % [mm] Manuel middeldiameter d_c

% --- Friktion og K-model ---
threadFrictionCoefficient = 0.15;    % [-] Gevindfriktion f
bearingFrictionCoefficient = 0.15;   % [-] Anlaegsfriktion f_c
nutFactorK = 0.20;                   % [-] Momentfaktor K i T=K*F_i*d

% --- Boltdata og graenser ---
boltTensileStressArea = 115;         % [mm^2] Traekspaendingsareal A_t
proofStrength = 380;                 % [MPa] Proof strength S_p
maximumProofLoadFraction = 1.00;     % [-] Tilladt andel af F_p=A_t*S_p

% --- Torsions- og von Mises-kontrol under tilspaending ---
torsionDiameterMode = "nominal";     % [-] "nominal" eller "manual"
torsionDiameterManual = NaN;         % [mm] Manuel diameter til W_p
requiredEquivalentSafety = 1.00;     % [-] Krav S_p/sigma_vm

% --- Visning og test ---
makeTorqueContributionPlot = true;   % [-] Plot af den detaljerede momentdeling
runCourseValidationTests = true;     % [-] Test mod kursusopgave 8-b2 og 8-b3

%% UNIT CHECK AND VALIDATION
validAnalysisModes = ["preloadToTorque", "torqueToPreload"];
assert(any(analysisMode == validAnalysisModes), ...
    'analysisMode skal vaere "preloadToTorque" eller "torqueToPreload".');

validTorqueModels = ["nutFactor", "exactCourse"];
assert(any(selectedTorqueModel == validTorqueModels), ...
    'selectedTorqueModel skal vaere "nutFactor" eller "exactCourse".');

assert(isscalar(nominalDiameter) && isfinite(nominalDiameter) && ...
    nominalDiameter > 0, 'd skal vaere positiv [mm].');
assert(isscalar(threadPitch) && isfinite(threadPitch) && ...
    threadPitch > 0, 'Gevindstigningen p skal vaere positiv [mm].');
assert(isscalar(numberOfThreadStarts) && ...
    numberOfThreadStarts == floor(numberOfThreadStarts) && ...
    numberOfThreadStarts >= 1, ...
    'Antal gevindstarter skal vaere et positivt heltal.');
assert(isscalar(threadHalfAngleDeg) && ...
    threadHalfAngleDeg > 0 && threadHalfAngleDeg < 90, ...
    'alpha skal ligge mellem 0 og 90 grader.');

assert(isscalar(threadFrictionCoefficient) && ...
    isfinite(threadFrictionCoefficient) && ...
    threadFrictionCoefficient >= 0, ...
    'Gevindfriktionen f skal vaere ikke-negativ.');
assert(isscalar(bearingFrictionCoefficient) && ...
    isfinite(bearingFrictionCoefficient) && ...
    bearingFrictionCoefficient >= 0, ...
    'Anlaegsfriktionen f_c skal vaere ikke-negativ.');
assert(isscalar(nutFactorK) && isfinite(nutFactorK) && ...
    nutFactorK > 0, 'K skal vaere positiv.');

assert(isscalar(boltTensileStressArea) && ...
    isfinite(boltTensileStressArea) && ...
    boltTensileStressArea > 0, 'A_t skal vaere positiv [mm^2].');
assert(isscalar(proofStrength) && isfinite(proofStrength) && ...
    proofStrength > 0, 'S_p skal vaere positiv [MPa].');
assert(isscalar(maximumProofLoadFraction) && ...
    maximumProofLoadFraction > 0 && ...
    maximumProofLoadFraction <= 1, ...
    'maximumProofLoadFraction skal ligge i intervallet ]0;1].');
assert(isscalar(requiredEquivalentSafety) && ...
    requiredEquivalentSafety > 0, ...
    'requiredEquivalentSafety skal vaere positiv.');

switch threadMeanDiameterMode
    case "fromMinorArea"
        assert(isscalar(minorArea) && isfinite(minorArea) && ...
            minorArea > 0, 'A_r skal vaere positiv [mm^2].');
        minorDiameter = sqrt(4*minorArea/pi);
        threadMeanDiameter = ...
            (nominalDiameter + minorDiameter)/2;

    case "fromMinorDiameter"
        assert(isscalar(minorDiameterManual) && ...
            isfinite(minorDiameterManual) && ...
            minorDiameterManual > 0 && ...
            minorDiameterManual < nominalDiameter, ...
            'Minor diameter skal ligge mellem 0 og d.');
        minorDiameter = minorDiameterManual;
        threadMeanDiameter = ...
            (nominalDiameter + minorDiameter)/2;

    case "manual"
        assert(isscalar(threadMeanDiameterManual) && ...
            isfinite(threadMeanDiameterManual) && ...
            threadMeanDiameterManual > 0 && ...
            threadMeanDiameterManual <= nominalDiameter, ...
            'Manuel d_m skal ligge i intervallet ]0;d].');
        threadMeanDiameter = threadMeanDiameterManual;
        minorDiameter = NaN;

    otherwise
        error('Ukendt threadMeanDiameterMode.');
end

switch bearingMeanDiameterMode
    case "fromDiameters"
        assert(isscalar(bearingOuterDiameter) && ...
            isfinite(bearingOuterDiameter) && ...
            bearingOuterDiameter > 0, ...
            'Ydre anlaegsdiameter skal vaere positiv.');
        assert(isscalar(bearingInnerDiameter) && ...
            isfinite(bearingInnerDiameter) && ...
            bearingInnerDiameter > 0 && ...
            bearingInnerDiameter < bearingOuterDiameter, ...
            'Indre anlaegsdiameter skal vaere mindre end den ydre.');
        bearingMeanDiameter = ...
            (bearingOuterDiameter + bearingInnerDiameter)/2;

    case "manual"
        assert(isscalar(bearingMeanDiameterManual) && ...
            isfinite(bearingMeanDiameterManual) && ...
            bearingMeanDiameterManual > 0, ...
            'Manuel d_c skal vaere positiv.');
        bearingMeanDiameter = bearingMeanDiameterManual;

    otherwise
        error('Ukendt bearingMeanDiameterMode.');
end

switch torsionDiameterMode
    case "nominal"
        torsionDiameter = nominalDiameter;
    case "manual"
        assert(isscalar(torsionDiameterManual) && ...
            isfinite(torsionDiameterManual) && ...
            torsionDiameterManual > 0, ...
            'Manuel torsionsdiameter skal vaere positiv.');
        torsionDiameter = torsionDiameterManual;
    otherwise
        error('Ukendt torsionDiameterMode.');
end

if analysisMode == "preloadToTorque"
    assert(isscalar(preloadForceInput) && ...
        isfinite(preloadForceInput) && preloadForceInput >= 0, ...
        'F_i skal vaere ikke-negativ [N].');
else
    assert(isscalar(tighteningTorqueInput) && ...
        isfinite(tighteningTorqueInput) && ...
        tighteningTorqueInput >= 0, ...
        'T skal vaere ikke-negativ [N*m].');
end

%% CALCULATION
lead = numberOfThreadStarts*threadPitch; % [mm/omdr.] Gevindets lead

torqueCoefficients = calculateTorqueCoefficients( ...
    nominalDiameter, threadMeanDiameter, bearingMeanDiameter, ...
    lead, threadHalfAngleDeg, threadFrictionCoefficient, ...
    bearingFrictionCoefficient, nutFactorK);

if selectedTorqueModel == "exactCourse"
    selectedTorqueCoefficient = ...
        torqueCoefficients.exactTotalCoefficient;
else
    selectedTorqueCoefficient = ...
        torqueCoefficients.nutFactorCoefficient;
end

% Koefficienterne har enheden mm, saa T[N*mm]=F_i[N]*koefficient[mm].
if analysisMode == "preloadToTorque"
    preloadForce = preloadForceInput;
    selectedTighteningTorque = ...
        preloadForce*selectedTorqueCoefficient; % [N*mm]
else
    tighteningTorqueInputNmm = ...
        tighteningTorqueInput*1e3;               % [N*mm]
    preloadForce = ...
        tighteningTorqueInputNmm/selectedTorqueCoefficient;
    selectedTighteningTorque = tighteningTorqueInputNmm;
end

torqueResult = calculateTorqueForPreload( ...
    preloadForce, torqueCoefficients);

proofLoad = boltTensileStressArea*proofStrength; % [N]
maximumAllowedPreload = ...
    maximumProofLoadFraction*proofLoad;           % [N]
maximumSelectedTorque = ...
    maximumAllowedPreload*selectedTorqueCoefficient; % [N*mm]

polarSectionModulus = ...
    pi*torsionDiameter^3/16;                      % [mm^3]
normalStressDuringTightening = ...
    preloadForce/boltTensileStressArea;           % [MPa]
torsionalStressDuringTightening = ...
    selectedTighteningTorque/polarSectionModulus; % [MPa]
vonMisesStressDuringTightening = sqrt( ...
    normalStressDuringTightening^2 + ...
    3*torsionalStressDuringTightening^2);         % [MPa]
equivalentProofSafety = ...
    proofStrength/vonMisesStressDuringTightening; % [-]

if torqueResult.exactTotalTorque > 0
    idealShare = 100*torqueResult.idealPitchTorque / ...
        torqueResult.exactTotalTorque;
    threadFrictionShare = ...
        100*torqueResult.threadFrictionTorque / ...
        torqueResult.exactTotalTorque;
    bearingFrictionShare = ...
        100*torqueResult.bearingFrictionTorque / ...
        torqueResult.exactTotalTorque;
    tighteningEfficiency = ...
        torqueResult.idealPitchTorque / ...
        torqueResult.exactTotalTorque;
else
    idealShare = NaN;
    threadFrictionShare = NaN;
    bearingFrictionShare = NaN;
    tighteningEfficiency = NaN;
end

exactVsNutFactorDifference = ...
    (torqueResult.nutFactorTorque - ...
    torqueResult.exactTotalTorque) / ...
    max(torqueResult.exactTotalTorque, eps);

contributionName = [ ...
    "Ideelt stigningsmoment"; ...
    "Ekstra gevindfriktion"; ...
    "Anlaegsfriktion"];
contributionTorqueNm = [ ...
    torqueResult.idealPitchTorque; ...
    torqueResult.threadFrictionTorque; ...
    torqueResult.bearingFrictionTorque]/1e3;
contributionPercent = [ ...
    idealShare; threadFrictionShare; bearingFrictionShare];

contributionTable = table( ...
    contributionName, contributionTorqueNm, contributionPercent, ...
    'VariableNames', { ...
    'Contribution', 'Torque_Nm', 'Share_percent'});

results = struct();
results.analysisMode = analysisMode;
results.selectedTorqueModel = selectedTorqueModel;
results.preloadForce = preloadForce;
results.lead = lead;
results.threadMeanDiameter = threadMeanDiameter;
results.minorDiameter = minorDiameter;
results.bearingMeanDiameter = bearingMeanDiameter;
results.leadAngleDeg = torqueCoefficients.leadAngleDeg;
results.exactDenominator = torqueCoefficients.exactDenominator;
results.exactNutFactor = torqueCoefficients.exactNutFactor;
results.inputNutFactor = nutFactorK;
results.idealPitchTorque = torqueResult.idealPitchTorque;
results.threadTorqueExact = torqueResult.threadTorqueExact;
results.threadFrictionTorque = torqueResult.threadFrictionTorque;
results.bearingFrictionTorque = torqueResult.bearingFrictionTorque;
results.exactTotalTorque = torqueResult.exactTotalTorque;
results.nutFactorTorque = torqueResult.nutFactorTorque;
results.selectedTighteningTorque = selectedTighteningTorque;
results.proofLoad = proofLoad;
results.maximumAllowedPreload = maximumAllowedPreload;
results.maximumSelectedTorque = maximumSelectedTorque;
results.normalStressDuringTightening = normalStressDuringTightening;
results.torsionalStressDuringTightening = ...
    torsionalStressDuringTightening;
results.vonMisesStressDuringTightening = ...
    vonMisesStressDuringTightening;
results.equivalentProofSafety = equivalentProofSafety;
results.tighteningEfficiency = tighteningEfficiency;
results.exactVsNutFactorDifference = exactVsNutFactorDifference;
results.contributionTable = contributionTable;

%% RESULTS
fprintf('\n============================================================\n');
fprintf('B3 - TILSPAENDINGSMOMENT OG FRIKTIONSBIDRAG\n');
fprintf('============================================================\n');
fprintf('Valgt beregningsretning             = %s\n', analysisMode);
fprintf('Valgt designmodel                   = %s\n', selectedTorqueModel);
fprintf('Nomineldiameter d                   = %.4f mm\n', nominalDiameter);
fprintf('Minor diameter                      = %.4f mm\n', minorDiameter);
fprintf('Gevindets middeldiameter d_m        = %.4f mm\n', ...
    threadMeanDiameter);
fprintf('Anlaeggets middeldiameter d_c       = %.4f mm\n', ...
    bearingMeanDiameter);
fprintf('Lead                                = %.4f mm/omdr.\n', lead);
fprintf('Stigningsvinkel lambda              = %.4f deg\n', ...
    torqueCoefficients.leadAngleDeg);
fprintf('Gevindfriktion f                    = %.4f\n', ...
    threadFrictionCoefficient);
fprintf('Anlaegsfriktion f_c                 = %.4f\n', ...
    bearingFrictionCoefficient);
fprintf('Eksakt afledt momentfaktor K_exact  = %.6f\n', ...
    torqueCoefficients.exactNutFactor);
fprintf('Indtastet momentfaktor K            = %.6f\n', nutFactorK);

fprintf('\nForspaendingskraft F_i               = %.3f N = %.3f kN\n', ...
    preloadForce, preloadForce/1e3);
fprintf('Ideelt stigningsmoment              = %.4f N*m\n', ...
    torqueResult.idealPitchTorque/1e3);
fprintf('Samlet gevindmoment                 = %.4f N*m\n', ...
    torqueResult.threadTorqueExact/1e3);
fprintf('Ekstra moment fra gevindfriktion    = %.4f N*m\n', ...
    torqueResult.threadFrictionTorque/1e3);
fprintf('Moment fra anlaegsfriktion          = %.4f N*m\n', ...
    torqueResult.bearingFrictionTorque/1e3);
fprintf('Detaljeret samlet moment            = %.4f N*m\n', ...
    torqueResult.exactTotalTorque/1e3);
fprintf('K-model: T=K*F_i*d                  = %.4f N*m\n', ...
    torqueResult.nutFactorTorque/1e3);
fprintf('VALGT tilspaendingsmoment           = %.4f N*m\n', ...
    selectedTighteningTorque/1e3);
fprintf('Relativ forskel K-model mod eksakt  = %.3f %%\n', ...
    100*exactVsNutFactorDifference);
fprintf('Ideel momentandel / virkningsgrad   = %.2f %%\n', ...
    100*tighteningEfficiency);

fprintf('\nDETALJERET MOMENTDELING\n');
disp(contributionTable);

fprintf('Proof load F_p=A_t*S_p              = %.3f kN\n', ...
    proofLoad/1e3);
fprintf('Maksimalt tilladt F_i               = %.3f kN\n', ...
    maximumAllowedPreload/1e3);
fprintf('Maksimalt moment med valgt model    = %.4f N*m\n', ...
    maximumSelectedTorque/1e3);

fprintf('\nSPAENDINGER UNDER TILSPAENDING\n');
fprintf('Normalspaending sigma               = %.3f MPa\n', ...
    normalStressDuringTightening);
fprintf('Polart modstandsmoment W_p          = %.3f mm^3\n', ...
    polarSectionModulus);
fprintf('Torsionsspaending tau               = %.3f MPa\n', ...
    torsionalStressDuringTightening);
fprintf('von Mises-spaending sigma_vm        = %.3f MPa\n', ...
    vonMisesStressDuringTightening);
fprintf('Aekvivalent sikkerhed S_p/sigma_vm  = %.4f\n', ...
    equivalentProofSafety);

%% AUTOMATIC CHECKS
if torqueCoefficients.exactDenominator > 0
    fprintf('OK: Naevneren i den detaljerede gevindmodel er positiv.\n');
else
    fprintf(['IKKE OK: Naevneren i gevindmodellen er ikke positiv. ', ...
        'Kontroller friktion og geometri.\n']);
end

if preloadForce <= maximumAllowedPreload*(1+1e-12)
    fprintf('OK: Forspaendingskraften overskrider ikke den valgte proof-graense.\n');
else
    fprintf('IKKE OK: Forspaendingskraften overskrider den valgte proof-graense.\n');
end

if selectedTighteningTorque <= maximumSelectedTorque*(1+1e-12)
    fprintf('OK: Det valgte moment ligger under momentgraensen.\n');
else
    fprintf('IKKE OK: Det valgte moment ligger over momentgraensen.\n');
end

if abs(exactVsNutFactorDifference) <= 0.10
    fprintf(['OK: K-modellen ligger inden for 10 %% af den detaljerede ', ...
        'model for de indtastede data.\n']);
else
    fprintf(['ADVARSEL: K-modellen afviger mere end 10 %% fra den ', ...
        'detaljerede model.\n']);
end

if equivalentProofSafety >= requiredEquivalentSafety
    fprintf('OK: Det valgte krav til aekvivalent proof-sikkerhed er opfyldt.\n');
else
    fprintf(['IKKE OK: von Mises-spaendingen opfylder ikke det valgte ', ...
        'proof-sikkerhedskrav under tilspaending.\n']);
end

if threadFrictionCoefficient == 0 && ...
        bearingFrictionCoefficient == 0
    fprintf('OK: Uden friktion er momentet lig det ideelle stigningsmoment.\n');
elseif tighteningEfficiency < 0.5
    fprintf(['ADVARSEL: Under halvdelen af momentet bidrager direkte ', ...
        'til arbejdet langs gevindets stigning; resten skyldes friktion.\n']);
end

%% PLOTS
if makeTorqueContributionPlot
    figure('Name', 'B3 - Momentbidrag');
    bar(contributionTorqueNm);
    xticks(1:numel(contributionName));
    xticklabels(contributionName);
    xtickangle(18);
    ylabel('Moment [N*m]');
    title('Detaljeret opdeling af tilspaendingsmoment');
    grid on;
end

%% PHYSICAL CONCLUSION
fprintf('\nFYSISK KONKLUSION\n');
fprintf(['Den detaljerede model viser, hvor meget af momentet der ', ...
    'bruges paa gevindstigning, gevindfriktion og anlaegsfriktion.\n']);

if selectedTorqueModel == "nutFactor"
    fprintf(['Designresultatet bruger kursusets K-model. Detaljeret ', ...
        'friktionsdeling er en parallel kontrol og summerer derfor ', ...
        'ikke noedvendigvis til det valgte K-moment.\n']);
else
    fprintf(['Designresultatet bruger den detaljerede kursusmodel med ', ...
        'de indtastede friktionskoefficienter og diametre.\n']);
end

fprintf(['Momentstyring giver kun den forventede forspaending, hvis ', ...
    'friktion og kontaktgeometri svarer til input.\n']);
fprintf(['Von Mises-kontrollen gaelder tilspaendingssituationen og ', ...
    'bruger det samlede valgte moment efter kursusopgave 8-b3.\n']);

%% OPTIONAL TEST CASES
if runCourseValidationTests
    courseTestResults = runB3CourseTests();
    results.courseTestResults = courseTestResults;

    fprintf('\nKONTROL MOD KURSUSOPGAVE 8-b OG GRAENSETILFAELDE\n');
    disp(courseTestResults);

    if all(courseTestResults.Status == "OK")
        fprintf('OK: Alle automatiske B3-tests er bestaaet.\n');
    else
        fprintf('IKKE OK: Mindst en automatisk B3-test fejler.\n');
    end
end

%% LOCAL FUNCTIONS
function coefficients = calculateTorqueCoefficients( ...
    d, dm, dc, lead, alphaDeg, f, fc, K)

    tanLeadAngle = lead/(pi*dm);
    secAlpha = 1/cosd(alphaDeg);
    exactDenominator = 1-f*tanLeadAngle*secAlpha;

    assert(exactDenominator > 0, ...
        ['Den detaljerede momentmodels naevner er <=0. ', ...
        'Kontroller f, lead, d_m og alpha.']);

    threadCoefficient = dm/2 * ...
        ((tanLeadAngle + f*secAlpha) / exactDenominator);
    bearingCoefficient = fc*dc/2;
    exactTotalCoefficient = ...
        threadCoefficient + bearingCoefficient;
    nutFactorCoefficient = K*d;
    idealPitchCoefficient = lead/(2*pi);

    coefficients = struct();
    coefficients.tanLeadAngle = tanLeadAngle;
    coefficients.leadAngleDeg = atand(tanLeadAngle);
    coefficients.secAlpha = secAlpha;
    coefficients.exactDenominator = exactDenominator;
    coefficients.threadCoefficient = threadCoefficient;
    coefficients.bearingCoefficient = bearingCoefficient;
    coefficients.exactTotalCoefficient = exactTotalCoefficient;
    coefficients.nutFactorCoefficient = nutFactorCoefficient;
    coefficients.idealPitchCoefficient = idealPitchCoefficient;
    coefficients.exactNutFactor = exactTotalCoefficient/d;
end

function torque = calculateTorqueForPreload(Fi, coefficients)
    idealPitchTorque = ...
        Fi*coefficients.idealPitchCoefficient;
    threadTorqueExact = ...
        Fi*coefficients.threadCoefficient;
    bearingFrictionTorque = ...
        Fi*coefficients.bearingCoefficient;
    exactTotalTorque = ...
        Fi*coefficients.exactTotalCoefficient;
    nutFactorTorque = ...
        Fi*coefficients.nutFactorCoefficient;

    threadFrictionTorque = ...
        threadTorqueExact-idealPitchTorque;

    torque = struct();
    torque.idealPitchTorque = idealPitchTorque;
    torque.threadTorqueExact = threadTorqueExact;
    torque.threadFrictionTorque = threadFrictionTorque;
    torque.bearingFrictionTorque = bearingFrictionTorque;
    torque.exactTotalTorque = exactTotalTorque;
    torque.nutFactorTorque = nutFactorTorque;
end

function testTable = runB3CourseTests()
    testName = strings(0,1);
    calculated = zeros(0,1);
    expected = zeros(0,1);
    tolerance = zeros(0,1);

    % Kursusopgave 8-b:
    d = 14;
    At = 115;
    Sp = 380;
    Fi = 0.90*At*Sp;
    K = 0.20;
    selectedTorqueNmm = K*Fi*d;

    % 8-b1: forspaendingsmoment.
    testName(end+1,1) = "8-b1: T ved 0.9*F_p [N*m]";
    calculated(end+1,1) = selectedTorqueNmm/1e3;
    expected(end+1,1) = 110.124;
    tolerance(end+1,1) = 1e-10;

    % 8-b2: proof load maa naa.
    proofLoad = At*Sp;
    testName(end+1,1) = "8-b2: T_max ved F_p [N*m]";
    calculated(end+1,1) = K*proofLoad*d/1e3;
    expected(end+1,1) = 122.36;
    tolerance(end+1,1) = 1e-10;

    % 8-b3: kursusets spaendinger under tilspaending.
    sigma = Fi/At;
    Wp = pi*d^3/16;
    tau = selectedTorqueNmm/Wp;
    sigmaVm = sqrt(sigma^2+3*tau^2);

    testName(end+1,1) = "8-b3: sigma [MPa]";
    calculated(end+1,1) = sigma;
    expected(end+1,1) = 342.000;
    tolerance(end+1,1) = 1e-10;

    testName(end+1,1) = "8-b3: W_p [mm^3]";
    calculated(end+1,1) = Wp;
    expected(end+1,1) = 538.783;
    tolerance(end+1,1) = 2e-6;

    testName(end+1,1) = "8-b3: tau [MPa]";
    calculated(end+1,1) = tau;
    expected(end+1,1) = 204.394;
    tolerance(end+1,1) = 2e-6;

    testName(end+1,1) = "8-b3: sigma_vm [MPa]";
    calculated(end+1,1) = sigmaVm;
    expected(end+1,1) = 492.234;
    tolerance(end+1,1) = 2e-6;

    % Simpelt graensetilfaelde uden friktion:
    % T skal blive F*lead/(2*pi).
    handD = 10;
    handDm = 9;
    handDc = 12;
    handLead = 1.5;
    handFi = 10e3;

    handCoefficients = calculateTorqueCoefficients( ...
        handD, handDm, handDc, handLead, 30, 0, 0, 0.20);
    handTorque = calculateTorqueForPreload( ...
        handFi, handCoefficients);

    testName(end+1,1) = "Haandkontrol: T uden friktion [N*m]";
    calculated(end+1,1) = handTorque.exactTotalTorque/1e3;
    expected(end+1,1) = handFi*handLead/(2*pi)/1e3;
    tolerance(end+1,1) = 1e-12;

    relativeError = ...
        abs(calculated-expected)./max(abs(expected), 1);
    status = repmat("OK", size(testName));
    status(relativeError > tolerance) = "IKKE OK";

    testTable = table( ...
        testName, calculated, expected, ...
        100*relativeError, 100*tolerance, status, ...
        'VariableNames', { ...
        'Test', 'Calculated', 'Expected', ...
        'RelativeError_percent', ...
        'Tolerance_percent', 'Status'});
end
