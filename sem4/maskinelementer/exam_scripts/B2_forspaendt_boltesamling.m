%% B2 - FORSPAENDT BOLTESAMLING UNDER YDRE AKSIALLAST
% Brug dette script naar:
%   - boltens og emnernes stivheder k_b og k_m allerede er kendt,
%   - en ydre aksial last P proever at separere samlingen,
%   - boltlast, restklemmekraft, proof-sikkerhed og separation skal kontrolleres.
%
% Brug ikke dette script naar:
%   - k_b og k_m endnu ikke er bestemt (brug B1 foerst),
%   - lasten er excentrisk eller fordeles ukendt mellem flere bolte,
%   - forskydning, udmattelse eller tilspaendingsmoment er hovedproblemet.
%
% Det skal bestemmes manuelt foerst:
%   - ydre separerende last P paa den analyserede bolt,
%   - traekspaendingsareal A_t fra gevindtabel,
%   - proof strength S_p fra materialetabel,
%   - boltstivhed k_b og emnestivhed k_m fra B1.
%
% Kursusgrundlag:
%   C   = k_b/(k_b+k_m)
%   P_b = C*P
%   P_m = (1-C)*P
%   F_b = F_i + C*P
%   F_m = F_i - (1-C)*P
%   n_p = S_p*A_t/(F_i+C*P)                    ligning (8-28)
%   n_L = (S_p*A_t-F_i)/(C*P)                  ligning (8-29)
%   n_0 = F_i/(P*(1-C))                        ligning (8-30)
%   F_i = 0.75*F_p for ikke-permanent samling  ligning (8-31)
%   F_i = 0.90*F_p for permanent samling       ligning (8-31)
%   F_p = A_t*S_p                              ligning (8-32)

clear; clc; close all;

%% ASSUMPTIONS AND MANUAL INPUT
% Enheder: N, mm og MPa (= N/mm^2).
% P er den separerende aksiallast PAA EN BOLT, ikke noedvendigvis total last.
% Lastfordeling i en boltgruppe skal derfor findes manuelt foerst.
% Bolt og emner antages lineart elastiske, og samlingen er ikke separeret.
% Kursusligningerne med C er kun gyldige frem til separation.
% Proof strength anvendes som kursusets graense mod permanent deformation.
% Forspaendingstab pga. saetning, temperatur og relaxation er ikke medtaget.
% Koncentrationsfaktorer og udmattelse behandles ikke i B2.

%% INPUT
% --- Kendte stivheder fra B1 ---
boltStiffness = 1.5e6;             % [N/mm] Boltstivhed k_b
memberStiffness = 3.5e6;           % [N/mm] Emnestivhed k_m

% --- Boltdata, manuelle tabelopslag ---
boltTensileStressArea = 84.3;         % [mm^2] Traekspaendingsareal A_t
proofStrengthMode = "manual";        % [-] "manual" eller "courseFromYield"
proofStrengthManual = 650;           % [MPa] Proof strength S_p, tabel 8-11
boltYieldStrength = 400;              % [MPa] Flydespaending S_y, kun alternativ
proofFromYieldFactor = 0.85;         % [-] Kursusregel S_p=0.85*S_y

% --- Forspaending ---
preloadMode = "recommended";         % [-] "recommended" eller "manual"
connectionType = "permanent";        % [-] "permanent" eller "nonPermanent"
recommendedFactorPermanent = 0.90;   % [-] Ligning (8-31)
recommendedFactorNonPermanent = 0.75;% [-] Ligning (8-31)
preloadForceManual = 30e3;           % [N] Manuel forspaendingskraft F_i

% --- Ydre separerende lasttilfaelde paa den analyserede bolt ---
loadCaseName = ["Kursuscase 8-b1"];  % [-] Navn paa hvert lasttilfaelde
externalSeparatingLoad = [10e3];     % [N] Ydre aksiallast P pr. bolt

% --- Designmaal til automatisk vurdering ---
requiredProofSafety = 1.00;          % [-] Mindste accepterede n_p
requiredSeparationSafety = 1.00;     % [-] Mindste accepterede n_0
calculationTolerance = 1e-9;         % [-] Numerisk graensetolerance

% --- Visning og selvtest ---
makeLoadDiagram = true;              % [-] Plot af bolt- og klemmekraft
runCourseValidationTests = true;     % [-] Test mod kursusopgave 8-b1

%% UNIT CHECK AND VALIDATION
assert(isscalar(boltStiffness) && isfinite(boltStiffness) && ...
    boltStiffness > 0, 'k_b skal vaere en positiv skalar [N/mm].');
assert(isscalar(memberStiffness) && isfinite(memberStiffness) && ...
    memberStiffness > 0, 'k_m skal vaere en positiv skalar [N/mm].');
assert(isscalar(boltTensileStressArea) && ...
    isfinite(boltTensileStressArea) && boltTensileStressArea > 0, ...
    'A_t skal vaere positivt [mm^2].');

validProofModes = ["manual", "courseFromYield"];
assert(any(proofStrengthMode == validProofModes), ...
    'proofStrengthMode skal vaere "manual" eller "courseFromYield".');

switch proofStrengthMode
    case "manual"
        proofStrength = proofStrengthManual;
    case "courseFromYield"
        assert(isscalar(boltYieldStrength) && ...
            isfinite(boltYieldStrength) && boltYieldStrength > 0, ...
            'S_y skal vaere positiv ved courseFromYield.');
        assert(isscalar(proofFromYieldFactor) && ...
            proofFromYieldFactor > 0 && proofFromYieldFactor <= 1, ...
            'proofFromYieldFactor skal ligge i intervallet ]0;1].');
        proofStrength = proofFromYieldFactor*boltYieldStrength;
end

assert(isscalar(proofStrength) && isfinite(proofStrength) && ...
    proofStrength > 0, 'S_p skal vaere positiv [MPa].');

validPreloadModes = ["recommended", "manual"];
assert(any(preloadMode == validPreloadModes), ...
    'preloadMode skal vaere "recommended" eller "manual".');

proofLoad = boltTensileStressArea*proofStrength; % [N] F_p=A_t*S_p

switch preloadMode
    case "recommended"
        validConnectionTypes = ["permanent", "nonPermanent"];
        assert(any(connectionType == validConnectionTypes), ...
            ['connectionType skal vaere "permanent" eller ', ...
             '"nonPermanent".']);

        if connectionType == "permanent"
            preloadFactorUsed = recommendedFactorPermanent;
        else
            preloadFactorUsed = recommendedFactorNonPermanent;
        end

        assert(preloadFactorUsed > 0 && preloadFactorUsed <= 1, ...
            'Den anbefalede forspaendingsfaktor skal ligge i ]0;1].');
        preloadForce = preloadFactorUsed*proofLoad;

    case "manual"
        assert(isscalar(preloadForceManual) && ...
            isfinite(preloadForceManual) && preloadForceManual >= 0, ...
            'Manuel forspaending F_i skal vaere ikke-negativ [N].');
        preloadForce = preloadForceManual;
        preloadFactorUsed = preloadForce/proofLoad;
end

externalSeparatingLoad = externalSeparatingLoad(:);
loadCaseName = string(loadCaseName(:));

assert(~isempty(externalSeparatingLoad), ...
    'Der skal angives mindst et lasttilfaelde.');
assert(all(isfinite(externalSeparatingLoad)) && ...
    all(externalSeparatingLoad >= 0), ...
    'Alle ydre separerende laster skal vaere ikke-negative [N].');
assert(numel(loadCaseName) == numel(externalSeparatingLoad), ...
    'loadCaseName og externalSeparatingLoad skal have samme laengde.');
assert(isscalar(requiredProofSafety) && requiredProofSafety > 0, ...
    'requiredProofSafety skal vaere positiv.');
assert(isscalar(requiredSeparationSafety) && ...
    requiredSeparationSafety > 0, ...
    'requiredSeparationSafety skal vaere positiv.');
assert(isscalar(calculationTolerance) && calculationTolerance >= 0, ...
    'calculationTolerance skal vaere ikke-negativ.');

%% CALCULATION
results = calculateB2Case( ...
    boltStiffness, memberStiffness, boltTensileStressArea, ...
    proofStrength, preloadForce, externalSeparatingLoad, ...
    loadCaseName, requiredProofSafety, ...
    requiredSeparationSafety, calculationTolerance);

results.proofStrengthMode = proofStrengthMode;
results.preloadMode = preloadMode;
results.connectionType = connectionType;
results.preloadFactorUsed = preloadFactorUsed;

% Designvindue for forspaending ved stoerste analyserede last.
maximumExternalLoad = max(externalSeparatingLoad);

minimumPreloadForSeparationTarget = ...
    requiredSeparationSafety*(1-results.stiffnessConstantC)* ...
    maximumExternalLoad;

maximumPreloadForProofTarget = ...
    proofLoad/requiredProofSafety - ...
    results.stiffnessConstantC*maximumExternalLoad;

preloadDesignWindowIsFeasible = ...
    maximumPreloadForProofTarget >= 0 && ...
    minimumPreloadForSeparationTarget <= maximumPreloadForProofTarget;

results.maximumExternalLoad = maximumExternalLoad;
results.minimumPreloadForSeparationTarget = ...
    minimumPreloadForSeparationTarget;
results.maximumPreloadForProofTarget = ...
    maximumPreloadForProofTarget;
results.preloadDesignWindowIsFeasible = ...
    preloadDesignWindowIsFeasible;

%% RESULTS
fprintf('\n============================================================\n');
fprintf('B2 - FORSPAENDT BOLTESAMLING UNDER YDRE AKSIALLAST\n');
fprintf('============================================================\n');
fprintf('Boltstivhed k_b                     = %.6g N/mm\n', ...
    boltStiffness);
fprintf('Emnestivhed k_m                     = %.6g N/mm\n', ...
    memberStiffness);
fprintf('Stivhedskonstant C                  = %.6f\n', ...
    results.stiffnessConstantC);
fprintf('Proof strength S_p                  = %.3f MPa\n', ...
    proofStrength);
fprintf('Traekspaendingsareal A_t            = %.3f mm^2\n', ...
    boltTensileStressArea);
fprintf('Proof load F_p=A_t*S_p              = %.3f N = %.3f kN\n', ...
    proofLoad, proofLoad/1e3);
fprintf('Forspaendingskraft F_i              = %.3f N = %.3f kN\n', ...
    preloadForce, preloadForce/1e3);
fprintf('Forspaending/proof load             = %.2f %%\n', ...
    100*preloadFactorUsed);
fprintf('Separationslast P_sep               = %.3f N = %.3f kN\n', ...
    results.separationExternalLoad, ...
    results.separationExternalLoad/1e3);
fprintf('Proof-graense for ydre last P_proof = %.3f N = %.3f kN\n', ...
    results.proofLimitedExternalLoad, ...
    results.proofLimitedExternalLoad/1e3);

fprintf('\nLASTTILFAELDE\n');
disp(results.loadCaseTable);

fprintf('DESIGNVINDUE VED P_max = %.3f kN\n', ...
    maximumExternalLoad/1e3);
fprintf('Mindste F_i for n_0 >= %.3f         = %.3f kN\n', ...
    requiredSeparationSafety, ...
    minimumPreloadForSeparationTarget/1e3);
fprintf('Stoerste F_i for n_p >= %.3f        = %.3f kN\n', ...
    requiredProofSafety, ...
    maximumPreloadForProofTarget/1e3);

if preloadDesignWindowIsFeasible
    fprintf(['OK: Der findes et forspaendingsinterval, som opfylder ', ...
        'begge designmaal ved P_max.\n']);
else
    fprintf(['IKKE OK: Kravene til proof-sikkerhed og separation kan ', ...
        'ikke opfyldes samtidigt ved P_max.\n']);
end

%% AUTOMATIC CHECKS
if results.stiffnessConstantC > 0 && ...
        results.stiffnessConstantC < 1
    fprintf('OK: C ligger fysisk korrekt mellem 0 og 1.\n');
else
    fprintf('IKKE OK: C ligger ikke mellem 0 og 1.\n');
end

if preloadForce < proofLoad*(1-calculationTolerance)
    fprintf('OK: Forspaendingen ligger under proof load.\n');
elseif abs(preloadForce-proofLoad) <= ...
        calculationTolerance*max(1, proofLoad)
    fprintf('ADVARSEL: Forspaendingen ligger paa proof load.\n');
else
    fprintf('IKKE OK: Forspaendingen overstiger proof load.\n');
end

if all(~results.separated)
    fprintf('OK: Ingen analyserede lasttilfaelde separerer samlingen.\n');
else
    fprintf(['IKKE OK: Mindst et lasttilfaelde naar eller overskrider ', ...
        'separationsgraensen. C-modellen er derefter ikke gyldig.\n']);
end

if all(results.proofSafety >= requiredProofSafety)
    fprintf('OK: Alle lasttilfaelde opfylder kravet til n_p.\n');
else
    fprintf('IKKE OK: Mindst et lasttilfaelde opfylder ikke kravet til n_p.\n');
end

if all(results.separationSafety >= requiredSeparationSafety)
    fprintf('OK: Alle lasttilfaelde opfylder kravet til n_0.\n');
else
    fprintf('IKKE OK: Mindst et lasttilfaelde opfylder ikke kravet til n_0.\n');
end

%% PLOTS
if makeLoadDiagram
    plotB2LoadDiagram( ...
        results, externalSeparatingLoad, loadCaseName, ...
        preloadForce, proofLoad);
end

%% PHYSICAL CONCLUSION
fprintf('\nFYSISK KONKLUSION\n');
fprintf(['Af en ekstra separerende last gaar C=%.4f i bolten, mens ', ...
    '1-C=%.4f aflaster de sammenklemte emner.\n'], ...
    results.stiffnessConstantC, ...
    1-results.stiffnessConstantC);

if any(results.separated)
    fprintf(['Samlingen separerer i mindst et lasttilfaelde. Resultater ', ...
        'baseret paa F_b=F_i+C*P er kun gyldige frem til P_sep.\n']);
elseif any(results.proofSafety < requiredProofSafety)
    fprintf(['Samlingen holder kontakt, men bolten opfylder ikke det ', ...
        'valgte krav til proof-sikkerhed.\n']);
else
    fprintf(['Samlingen holder kontakt, og bolten opfylder det valgte ', ...
        'proof-krav for alle analyserede lasttilfaelde.\n']);
end

fprintf(['Resultatet afhaenger direkte af den manuelt bestemte last ', ...
    'pr. bolt samt k_b, k_m, A_t og S_p.\n']);

%% OPTIONAL TEST CASES
if runCourseValidationTests
    courseTestResults = runB2CourseTests();
    results.courseTestResults = courseTestResults;

    fprintf('\nKONTROL MOD KURSUSOPGAVE 8-b1 OG SIMPLE GRAENSETILFAELDE\n');
    disp(courseTestResults);

    if all(courseTestResults.Status == "OK")
        fprintf('OK: Alle automatiske B2-tests er bestaaet.\n');
    else
        fprintf('IKKE OK: Mindst en automatisk B2-test fejler.\n');
    end
end

%% LOCAL FUNCTIONS
function results = calculateB2Case( ...
    kb, km, At, Sp, Fi, P, caseName, ...
    requiredNp, requiredN0, tolerance)

    C = kb/(kb+km);
    proofLoad = At*Sp;

    boltLoadIncrement = C.*P;              % [N] P_b
    memberUnload = (1-C).*P;               % [N] P_m
    boltForce = Fi + boltLoadIncrement;    % [N] F_b
    remainingClampForce = Fi-memberUnload; % [N] F_m
    boltStress = boltForce./At;             % [MPa]

    proofSafety = proofLoad./boltForce;     % [-] n_p

    separationSafety = inf(size(P));        % [-] n_0
    positiveMemberUnload = memberUnload > 0;
    separationSafety(positiveMemberUnload) = ...
        Fi./memberUnload(positiveMemberUnload);

    proofLoadFactor = inf(size(P));         % [-] n_L
    positiveExternalLoad = P > 0;
    proofLoadFactor(positiveExternalLoad) = ...
        (proofLoad-Fi)./(C.*P(positiveExternalLoad));

    separationExternalLoad = Fi/(1-C);

    if C > 0
        proofLimitedExternalLoad = (proofLoad-Fi)/C;
    else
        proofLimitedExternalLoad = Inf;
    end

    forceTolerance = tolerance*max([1; abs(Fi); abs(proofLoad); abs(P)]);
    separated = remainingClampForce <= forceTolerance;
    proofExceeded = boltForce > ...
        proofLoad + tolerance*max(1, proofLoad);

    status = strings(size(P));
    for i = 1:numel(P)
        atSeparationBoundary = ...
            abs(remainingClampForce(i)) <= forceTolerance;
        atProofBoundary = ...
            abs(boltForce(i)-proofLoad) <= ...
            tolerance*max(1, proofLoad);

        if proofExceeded(i) && separated(i)
            status(i) = "IKKE OK: proof + separation";
        elseif proofExceeded(i)
            status(i) = "IKKE OK: proof";
        elseif remainingClampForce(i) < -forceTolerance
            status(i) = "IKKE OK: separation";
        elseif atSeparationBoundary
            status(i) = "ADVARSEL: ved separation";
        elseif atProofBoundary
            status(i) = "ADVARSEL: ved proof";
        elseif proofSafety(i) < requiredNp || ...
                separationSafety(i) < requiredN0
            status(i) = "IKKE OK: sikkerhedskrav";
        else
            status(i) = "OK";
        end
    end

    loadCaseTable = table( ...
        caseName, P, boltLoadIncrement, memberUnload, ...
        boltForce, remainingClampForce, boltStress, ...
        proofSafety, separationSafety, proofLoadFactor, status, ...
        'VariableNames', { ...
        'Case', 'P_N', 'BoltIncrement_N', 'MemberUnload_N', ...
        'BoltForce_N', 'ClampForce_N', 'BoltStress_MPa', ...
        'ProofSafety_np', 'SeparationSafety_n0', ...
        'ProofLoadFactor_nL', 'Status'});

    results = struct();
    results.stiffnessConstantC = C;
    results.proofLoad = proofLoad;
    results.preloadForce = Fi;
    results.externalSeparatingLoad = P;
    results.boltLoadIncrement = boltLoadIncrement;
    results.memberUnload = memberUnload;
    results.boltForce = boltForce;
    results.remainingClampForce = remainingClampForce;
    results.boltStress = boltStress;
    results.proofSafety = proofSafety;
    results.separationSafety = separationSafety;
    results.proofLoadFactor = proofLoadFactor;
    results.separationExternalLoad = separationExternalLoad;
    results.proofLimitedExternalLoad = proofLimitedExternalLoad;
    results.separated = separated;
    results.proofExceeded = proofExceeded;
    results.status = status;
    results.loadCaseTable = loadCaseTable;
end

function plotB2LoadDiagram( ...
    results, loadCases, caseNames, Fi, proofLoad)

    candidateLimits = [ ...
        1.15*max(loadCases), ...
        1.05*results.separationExternalLoad, ...
        1.05*results.proofLimitedExternalLoad];

    candidateLimits = candidateLimits( ...
        isfinite(candidateLimits) & candidateLimits > 0);

    if isempty(candidateLimits)
        plotMaximumLoad = 1;
    else
        plotMaximumLoad = max(candidateLimits);
    end

    externalLoadPlot = linspace(0, plotMaximumLoad, 400);
    boltForcePlot = Fi + ...
        results.stiffnessConstantC*externalLoadPlot;
    clampForcePlot = Fi - ...
        (1-results.stiffnessConstantC)*externalLoadPlot;

    figure('Name', 'B2 - Lastfordeling i forspaendt samling');
    plot(externalLoadPlot/1e3, boltForcePlot/1e3, ...
        'LineWidth', 1.5);
    hold on;
    plot(externalLoadPlot/1e3, clampForcePlot/1e3, ...
        'LineWidth', 1.5);
    yline(proofLoad/1e3, '--', 'Proof load F_p');
    yline(0, ':', 'Nul klemmekraft');
    xline(results.separationExternalLoad/1e3, '--', ...
        'P_{sep}');

    scatter(loadCases/1e3, results.boltForce/1e3, 45, ...
        'DisplayName', 'Analyseret boltlast');
    scatter(loadCases/1e3, results.remainingClampForce/1e3, 45, ...
        'DisplayName', 'Analyseret klemmekraft');

    xlabel('Ydre separerende last P pr. bolt [kN]');
    ylabel('Kraft [kN]');
    title('Boltlast og restklemmekraft frem til separation');
    legend({'F_b=F_i+C P', 'F_m=F_i-(1-C)P', ...
        'Proof load', 'Nul klemmekraft', ...
        'Separationslast', 'Analyseret boltlast', ...
        'Analyseret klemmekraft'}, ...
        'Location', 'best');
    grid on;
    hold off;

    % Navne vises i kommandovinduet; plotmarkoerer kan overlappe.
    if numel(caseNames) > 1
        fprintf('Plot indeholder %d analyserede lasttilfaelde.\n', ...
            numel(caseNames));
    end
end

function testTable = runB2CourseTests()
    toleranceCourse = 2e-3; % 0.2 % pga. afrundede kursusfacitter.

    testName = strings(0,1);
    calculated = zeros(0,1);
    expected = zeros(0,1);
    relativeTolerance = zeros(0,1);

    % Kursusopgave 8-b1:
    % M14x2, A_t=115 mm^2, S_p=380 MPa, permanent samling,
    % k_b=8.837e5 N/mm, k_m=6.323e6 N/mm og P=10 kN.
    kb = 8.837e5;
    km = 6.323e6;
    At = 115;
    Sp = 380;
    Fi = 0.90*At*Sp;
    P = 10e3;

    course = calculateB2Case( ...
        kb, km, At, Sp, Fi, P, "8-b1", ...
        1.0, 1.0, 1e-9);

    testName(end+1,1) = "8-b1: C";
    calculated(end+1,1) = course.stiffnessConstantC;
    expected(end+1,1) = 0.123;
    relativeTolerance(end+1,1) = 5e-3;

    testName(end+1,1) = "8-b1: F_i [N]";
    calculated(end+1,1) = Fi;
    expected(end+1,1) = 39.33e3;
    relativeTolerance(end+1,1) = toleranceCourse;

    testName(end+1,1) = "8-b1: n_p";
    calculated(end+1,1) = course.proofSafety;
    expected(end+1,1) = 1.078;
    relativeTolerance(end+1,1) = toleranceCourse;

    testName(end+1,1) = "8-b1: n_0";
    calculated(end+1,1) = course.separationSafety;
    expected(end+1,1) = 4.483;
    relativeTolerance(end+1,1) = toleranceCourse;

    % Simpel haandkontrol: k_b=k_m giver C=0.5.
    hand = calculateB2Case( ...
        1e6, 1e6, 100, 300, 10e3, 4e3, ...
        "Haandkontrol", 1.0, 1.0, 1e-9);

    testName(end+1,1) = "Haandkontrol: F_b [N]";
    calculated(end+1,1) = hand.boltForce;
    expected(end+1,1) = 12e3;
    relativeTolerance(end+1,1) = 1e-12;

    testName(end+1,1) = "Haandkontrol: F_m [N]";
    calculated(end+1,1) = hand.remainingClampForce;
    expected(end+1,1) = 8e3;
    relativeTolerance(end+1,1) = 1e-12;

    % Graensetilfaelde: P=25 kN skal give negativ lineart beregnet
    % klemmekraft og dermed separation i samme haandmodel.
    failure = calculateB2Case( ...
        1e6, 1e6, 100, 300, 10e3, 25e3, ...
        "Fejlcase", 1.0, 1.0, 1e-9);

    testName(end+1,1) = "Fejlcase: separation flag";
    calculated(end+1,1) = double(failure.separated);
    expected(end+1,1) = 1;
    relativeTolerance(end+1,1) = 0;

    absoluteScale = max(abs(expected), 1);
    relativeError = abs(calculated-expected)./absoluteScale;

    status = repmat("OK", size(testName));
    status(relativeError > relativeTolerance) = "IKKE OK";

    testTable = table( ...
        testName, calculated, expected, ...
        100*relativeError, 100*relativeTolerance, status, ...
        'VariableNames', { ...
        'Test', 'Calculated', 'Expected', ...
        'RelativeError_percent', ...
        'Tolerance_percent', 'Status'});
end
