%% F1 - SERIE- OG PARALLELKOBLING AF LINEÆRE FJEDRE
% Brug dette script når:
%   - fjederkonstanterne k_i er kendt;
%   - fjedrene er koblet i serie eller parallelt;
%   - kraft, deformation, kraftfordeling eller resultantens placering søges;
%   - en STIV bjælke bæres af to serie-/parallelkoblede fjedersystemer.
%
% Brug ikke dette script når:
%   - k skal beregnes fra skruefjederens geometri, spænding eller materiale
%     (brug F2/F3);
%   - bjælken selv bøjer mærkbart;
%   - fjedrene er ikke-lineære eller har slup, stop eller ukendt forspænding.
%
% Manuel modellering:
%   Afgør først hvilke fjedre der er i serie/parallelt, og bestem eventuelle
%   lastpositioner fra et fritlegemediagram.
%
% Kursusmetode:
%   Parallel: delta_tot = delta_i, F_tot = sum(F_i), k_tot = sum(k_i)
%   Serie:    F_tot = F_i, delta_tot = sum(delta_i),
%             1/k_tot = sum(1/k_i)
%
% Enheder i hele scriptet: N, mm og N/mm.

clearvars
clc
close all

%% ASSUMPTIONS AND MANUAL INPUT
% - Alle fjedre er lineære: F = k*delta.
% - Positive kræfter og deformationer regnes nedad.
% - Parallelle fjedre er fastgjort til en stiv plade og får samme deformation.
% - Seriekoblede fjedre overfører samme kraft.
% - Bjælkecasen har præcis to fjederunderstøtninger og en stiv bjælke.
% - En ren trykfjeder kan ikke optage negativ reaktion uden fastholdelse.

%% INPUT
calculationCase = "parallel";      % [-] "parallel", "series" eller "rigidBeam"
makePlot = true;                   % [-] Vis et relevant teknisk plot
runTests = true;                   % [-] Kør kursus- og kontroltests
testTolerance = 1e-9;              % [-] Absolut tolerans i test

% Input til "parallel" og "series"
knownQuantity = "deformation";     % [-] "force" eller "deformation"
springStiffness = [10, 15];        % [N/mm] k_i; NaN kun ved ukendt k_i i serie
totalForce = NaN;                  % [N] Bruges når knownQuantity = "force"
totalDeformation = 20;             % [mm] Bruges når knownQuantity = "deformation"
knownSpringDeformation = [NaN, NaN]; % [mm] delta_i til bestemmelse af ukendt k_i
springPositions = [0, 50];         % [mm] x_i i parallelcase; [] fravælger x_R

% Input til "rigidBeam"
supportConnection = ["parallel","series"]; % [-] Venstre og højre kobling
supportSpringStiffness = {[200,150],[200,150]}; % [N/mm] k_i i hvert system
supportPositions = [0, 2800];      % [mm] [x_A x_B]
externalLoads = 24000;             % [N] Punktlaster, positive nedad
externalLoadPositions = 1400;      % [mm] Position for hver punktlast

%% UNIT CHECK AND VALIDATION
assert(isscalar(calculationCase) && ...
    any(calculationCase == ["parallel","series","rigidBeam"]), ...
    'calculationCase skal være "parallel", "series" eller "rigidBeam".')
assert(islogical(makePlot) && isscalar(makePlot), ...
    'makePlot skal være true eller false.')
assert(islogical(runTests) && isscalar(runTests), ...
    'runTests skal være true eller false.')
assert(isfinite(testTolerance) && testTolerance > 0, ...
    'testTolerance skal være positiv.')

switch calculationCase
    case {"parallel","series"}
        assert(isnumeric(springStiffness) && isvector(springStiffness) ...
            && ~isempty(springStiffness), ...
            'springStiffness skal være en ikke-tom numerisk vektor.')
        assert(isscalar(knownQuantity) && ...
            any(knownQuantity == ["force","deformation"]), ...
            'knownQuantity skal være "force" eller "deformation".')
    case "rigidBeam"
        assert(isstring(supportConnection) && numel(supportConnection) == 2, ...
            'supportConnection skal indeholde to koblingstyper.')
        assert(iscell(supportSpringStiffness) && ...
            numel(supportSpringStiffness) == 2, ...
            'supportSpringStiffness skal have én celle pr. understøtning.')
        assert(isnumeric(supportPositions) && numel(supportPositions) == 2 ...
            && all(isfinite(supportPositions)) ...
            && supportPositions(2) > supportPositions(1), ...
            'supportPositions skal være [x_A x_B] med x_B > x_A.')
        assert(isnumeric(externalLoads) && isnumeric(externalLoadPositions) ...
            && isvector(externalLoads) && isvector(externalLoadPositions) ...
            && numel(externalLoads) == numel(externalLoadPositions) ...
            && ~isempty(externalLoads), ...
            'Der skal være én position for hver last.')
        assert(all(isfinite(externalLoads)) && all(externalLoads >= 0), ...
            'externalLoads skal være endelige og ikke-negative.')
        assert(all(isfinite(externalLoadPositions)), ...
            'externalLoadPositions skal være endelige.')
end

%% CALCULATION
switch calculationCase
    case {"parallel","series"}
        results = solveSpringConnection(calculationCase, springStiffness, ...
            knownQuantity, totalForce, totalDeformation, ...
            knownSpringDeformation, springPositions);
    case "rigidBeam"
        results = solveRigidBeam(supportConnection, ...
            supportSpringStiffness, supportPositions, ...
            externalLoads, externalLoadPositions);
end

%% RESULTS
fprintf('\n================ F1 RESULTATER ================\n')
fprintf('Case: %s\n', calculationCase)

switch calculationCase
    case {"parallel","series"}
        fprintf('k_tot       = %.6g N/mm\n', results.equivalentStiffness)
        fprintf('F_tot       = %.6g N\n', results.totalForce)
        fprintf('delta_tot   = %.6g mm\n', results.totalDeformation)
        disp(table((1:numel(results.springStiffness)).', ...
            results.springStiffness.', results.springForce.', ...
            results.springDeformation.', ...
            'VariableNames', {'Fjeder','k_N_pr_mm','F_N','delta_mm'}))
        if ~isnan(results.resultantPosition)
            fprintf('x_R         = %.6g mm\n', results.resultantPosition)
        end
        if any(results.inferredStiffness)
            fprintf('Beregnet ukendt k for fjeder(e): %s\n', ...
                mat2str(find(results.inferredStiffness)))
        end

    case "rigidBeam"
        fprintf('k_A, k_B    = [%.6g, %.6g] N/mm\n', ...
            results.supportEquivalentStiffness)
        fprintf('R_A, R_B    = [%.6g, %.6g] N\n', results.supportReaction)
        fprintf('delta_A/B   = [%.6g, %.6g] mm\n', ...
            results.supportDeformation)
        fprintf('delta_B-A   = %.6g mm\n', results.deformationDifference)
        fprintf('phi         = %.6g deg\n', results.beamAngleDeg)
        disp(table(["A";"B"], supportConnection(:), ...
            results.supportEquivalentStiffness(:), ...
            results.supportReaction(:), results.supportDeformation(:), ...
            'VariableNames', ...
            {'Understoetning','Kobling','k_N_pr_mm','R_N','delta_mm'}))
end

%% AUTOMATIC CHECKS
if all(cell2mat(struct2cell(results.checks)))
    fprintf('OK: Alle automatiske ligevægts-/kompatibilitetskontroller består.\n')
else
    fprintf('IKKE OK: Mindst én automatisk kontrol fejler.\n')
    disp(results.checks)
end

if calculationCase == "rigidBeam" && any(results.supportReaction < 0)
    fprintf(['ADVARSEL: En reaktion er negativ. En ikke-fastgjort trykfjeder ' ...
        'kan miste kontakten.\n'])
end

%% PLOTS
if makePlot
    switch calculationCase
        case "parallel"
            figure('Name','F1 - parallelkobling')
            bar(1:numel(results.springForce), results.springForce)
            xlabel('Fjeder nr. [-]')
            ylabel('Fjederkraft F_i [N]')
            title('Kraftfordeling i parallelkobling')
            grid on

        case "series"
            figure('Name','F1 - seriekobling')
            bar(1:numel(results.springDeformation), ...
                results.springDeformation)
            xlabel('Fjeder nr. [-]')
            ylabel('Deformation \delta_i [mm]')
            title('Deformationsfordeling i seriekobling')
            grid on

        case "rigidBeam"
            figure('Name','F1 - stiv bjælke på fjedre')
            plot(results.supportPositions, [0 0], '--', 'LineWidth', 1.2)
            hold on
            plot(results.supportPositions, -results.supportDeformation, ...
                '-o', 'LineWidth', 1.5)
            scatter(results.externalLoadPositions, ...
                -results.loadPointDeformation, 45, 'filled')
            hold off
            xlabel('Position x [mm]')
            ylabel('Lodret position [mm]')
            title('Udeformeret og deformeret stiv bjælke')
            legend('Udeformeret','Deformeret','Lastpunkt', ...
                'Location','best')
            grid on
    end
end

%% PHYSICAL CONCLUSION
switch calculationCase
    case "parallel"
        [~, index] = max(results.springStiffness);
        fprintf(['Fysisk konklusion: Alle fjedre har samme deformation. ' ...
            'Fjeder %d er stivest og optager derfor størst kraft.\n'], index)
    case "series"
        [~, index] = min(results.springStiffness);
        fprintf(['Fysisk konklusion: Alle fjedre har samme kraft. ' ...
            'Fjeder %d er blødest og får derfor størst deformation.\n'], index)
    case "rigidBeam"
        if results.beamAngleDeg > 0
            direction = 'højre side synker mest';
        elseif results.beamAngleDeg < 0
            direction = 'venstre side synker mest';
        else
            direction = 'bjælken forbliver vandret';
        end
        fprintf(['Fysisk konklusion: Rotation skyldes forskellen i ' ...
            'understøtningernes deformationer; %s.\n'], direction)
end

%% OPTIONAL TEST CASES
% Testene omfatter kursusopgave 1.1, 1.2 og 1.3, en håndkontrol med én
% fjeder samt et nul-last randtilfælde.
if runTests
    testReport = runF1Tests(testTolerance);
    disp(testReport)
    assert(all(testReport.Bestaaet), ...
        'Mindst én F1-test fejlede. Se testReport.')
    fprintf('OK: Alle kursus-, hånd- og randtests består.\n')
end

%% LOCAL FUNCTIONS
function out = solveSpringConnection(type, k, knownQuantity, ...
        Ftot, deltaTot, knownDelta, positions)

    type = lower(string(type));
    knownQuantity = lower(string(knownQuantity));
    k = k(:).';
    knownDelta = knownDelta(:).';
    inferred = isnan(k);

    assert(all(isnan(k) | (isfinite(k) & k > 0)), ...
        'Kendte k_i skal være positive; ukendte angives med NaN.')

    if any(inferred)
        assert(type == "series" && knownQuantity == "force", ...
            'Ukendt k_i understøttes kun i seriecase med kendt kraft.')
        assert(numel(knownDelta) == numel(k) && ...
            all(isfinite(knownDelta(inferred))) && ...
            all(knownDelta(inferred) > 0), ...
            'Angiv positiv knownSpringDeformation for hvert ukendt k_i.')
        assert(isfinite(Ftot) && isscalar(Ftot) && Ftot > 0, ...
            'totalForce skal være positiv for at bestemme ukendt k_i.')
        k(inferred) = Ftot./knownDelta(inferred);
    end

    if type == "parallel"
        kEq = sum(k);
    elseif type == "series"
        kEq = 1/sum(1./k);
    else
        error('Ukendt koblingstype.')
    end

    if knownQuantity == "force"
        assert(isfinite(Ftot) && isscalar(Ftot) && Ftot >= 0, ...
            'totalForce skal være en ikke-negativ skalar.')
        deltaTot = Ftot/kEq;
    else
        assert(isfinite(deltaTot) && isscalar(deltaTot) && deltaTot >= 0, ...
            'totalDeformation skal være en ikke-negativ skalar.')
        Ftot = kEq*deltaTot;
    end

    if type == "parallel"
        deltaEach = repmat(deltaTot, size(k));
        forceEach = k.*deltaEach;
        forceResidual = abs(sum(forceEach)-Ftot);
        deformationResidual = max(abs(deltaEach-deltaTot));
    else
        forceEach = repmat(Ftot, size(k));
        deltaEach = Ftot./k;
        deltaTot = sum(deltaEach);
        forceResidual = max(abs(forceEach-Ftot));
        deformationResidual = abs(sum(deltaEach)-deltaTot);
    end

    if type == "parallel" && ~isempty(positions)
        positions = positions(:).';
        assert(numel(positions) == numel(k) && all(isfinite(positions)), ...
            'springPositions skal have én endelig position pr. fjeder.')
        if Ftot > 0
            xResultant = sum(forceEach.*positions)/Ftot;
        else
            xResultant = NaN;
        end
        resultantOK = isnan(xResultant) || ...
            (xResultant >= min(positions) && xResultant <= max(positions));
    else
        positions = [];
        xResultant = NaN;
        resultantOK = true;
    end

    springEnergy = 0.5*sum(forceEach.*deltaEach);
    equivalentEnergy = 0.5*Ftot*deltaTot;

    out.case = type;
    out.springStiffness = k;
    out.inferredStiffness = inferred;
    out.equivalentStiffness = kEq;
    out.springForce = forceEach;
    out.springDeformation = deltaEach;
    out.totalForce = Ftot;
    out.totalDeformation = deltaTot;
    out.springPositions = positions;
    out.resultantPosition = xResultant;
    out.checks.forceCompatibility = ...
        forceResidual <= 1e-10*max(1,abs(Ftot));
    out.checks.deformationCompatibility = ...
        deformationResidual <= 1e-10*max(1,abs(deltaTot));
    out.checks.energyConsistency = ...
        abs(springEnergy-equivalentEnergy) <= ...
        1e-10*max(1,abs(equivalentEnergy));
    out.checks.resultantInsideSpan = resultantOK;
end

function out = solveRigidBeam(connection, springSets, supportX, loads, loadX)
    connection = lower(string(connection(:).'));
    supportX = supportX(:).';
    loads = loads(:).';
    loadX = loadX(:).';

    assert(numel(connection) == 2 && ...
        all(ismember(connection,["parallel","series"])), ...
        'Der skal være to gyldige koblingstyper.')

    kSupport = zeros(1,2);
    internal = cell(1,2);
    for i = 1:2
        k = springSets{i}(:).';
        assert(~isempty(k) && all(isfinite(k)) && all(k > 0), ...
            'Alle lokale fjederkonstanter skal være positive.')
        if connection(i) == "parallel"
            kSupport(i) = sum(k);
        else
            kSupport(i) = 1/sum(1./k);
        end
        internal{i}.springStiffness = k;
    end

    span = supportX(2)-supportX(1);
    totalLoad = sum(loads);
    RB = sum(loads.*(loadX-supportX(1)))/span;
    RA = totalLoad-RB;
    reaction = [RA,RB];
    supportDelta = reaction./kSupport;

    for i = 1:2
        k = internal{i}.springStiffness;
        if connection(i) == "parallel"
            internal{i}.springDeformation = ...
                repmat(supportDelta(i),size(k));
            internal{i}.springForce = ...
                k.*internal{i}.springDeformation;
        else
            internal{i}.springForce = repmat(reaction(i),size(k));
            internal{i}.springDeformation = reaction(i)./k;
        end
    end

    deltaDifference = supportDelta(2)-supportDelta(1);
    angleDeg = atan2d(deltaDifference,span);
    loadPointDelta = supportDelta(1) + ...
        deltaDifference.*(loadX-supportX(1))/span;

    forceResidual = abs(sum(reaction)-totalLoad);
    momentResidual = abs(RB*span - ...
        sum(loads.*(loadX-supportX(1))));
    springEnergy = 0.5*sum(reaction.*supportDelta);
    externalEnergy = 0.5*sum(loads.*loadPointDelta);

    out.case = "rigidBeam";
    out.supportConnection = connection;
    out.supportEquivalentStiffness = kSupport;
    out.supportPositions = supportX;
    out.externalLoads = loads;
    out.externalLoadPositions = loadX;
    out.supportReaction = reaction;
    out.supportDeformation = supportDelta;
    out.deformationDifference = deltaDifference;
    out.beamAngleDeg = angleDeg;
    out.loadPointDeformation = loadPointDelta;
    out.internalSupportResults = internal;
    out.checks.forceEquilibrium = ...
        forceResidual <= 1e-10*max(1,abs(totalLoad));
    out.checks.momentEquilibrium = ...
        momentResidual <= 1e-10*max(1,abs(RB*span));
    out.checks.energyConsistency = ...
        abs(springEnergy-externalEnergy) <= ...
        1e-10*max(1,abs(externalEnergy));
end

function report = runF1Tests(tol)
    names = ["Kursus 1.1 - parallel/resultant"; ...
             "Kursus 1.2 - serie/ukendt k"; ...
             "Kursus 1.3 - stiv bjælke"; ...
             "Håndkontrol - én fjeder"; ...
             "Randtilfælde - nul last"];
    passed = false(5,1);
    maxError = NaN(5,1);
    calculated = strings(5,1);

    r = solveSpringConnection("parallel",[10,15],"deformation", ...
        NaN,20,[NaN,NaN],[0,50]);
    actual = [r.springForce,r.totalForce,r.equivalentStiffness, ...
        r.resultantPosition];
    expected = [200,300,500,25,30];
    maxError(1) = max(abs(actual-expected));
    passed(1) = maxError(1) <= tol;
    calculated(1) = sprintf('Ftot=%.6g N, ktot=%.6g N/mm, xR=%.6g mm', ...
        r.totalForce,r.equivalentStiffness,r.resultantPosition);

    r = solveSpringConnection("series",[NaN,15],"force", ...
        300,NaN,[20,NaN],[]);
    actual = [r.springStiffness,r.springDeformation, ...
        r.equivalentStiffness,r.totalDeformation];
    expected = [15,15,20,20,7.5,40];
    maxError(2) = max(abs(actual-expected));
    passed(2) = maxError(2) <= tol;
    calculated(2) = sprintf('ktot=%.6g N/mm, deltatot=%.6g mm', ...
        r.equivalentStiffness,r.totalDeformation);

    weight = 800*3*10; % [N] Kursusdata: 800 kg/m, 3 m, g=10 m/s^2
    r = solveRigidBeam(["parallel","series"], ...
        {[200,150],[200,150]},[0,2800],weight,1400);
    actual = [r.supportEquivalentStiffness,r.supportReaction, ...
        r.supportDeformation,r.deformationDifference,r.beamAngleDeg];
    expected = [350,85.7142857142857,12000,12000, ...
        34.2857142857143,140,105.714285714286,2.16218103357005];
    maxError(3) = max(abs(actual-expected));
    passed(3) = maxError(3) <= tol;
    calculated(3) = sprintf('delta=[%.6g %.6g] mm, phi=%.6g deg', ...
        r.supportDeformation(1),r.supportDeformation(2),r.beamAngleDeg);

    r = solveSpringConnection("parallel",10,"deformation", ...
        NaN,2,NaN,0);
    actual = [r.equivalentStiffness,r.totalForce,r.totalDeformation];
    expected = [10,20,2];
    maxError(4) = max(abs(actual-expected));
    passed(4) = maxError(4) <= tol;
    calculated(4) = sprintf('ktot=%.6g, Ftot=%.6g, deltatot=%.6g', ...
        actual);

    r = solveSpringConnection("series",[10,20],"force", ...
        0,NaN,[NaN,NaN],[]);
    actual = [r.totalForce,r.totalDeformation,r.springDeformation];
    expected = [0,0,0,0];
    maxError(5) = max(abs(actual-expected));
    passed(5) = maxError(5) <= tol;
    calculated(5) = sprintf('Ftot=%.6g, deltatot=%.6g', ...
        r.totalForce,r.totalDeformation);

    report = table(names,calculated,maxError,passed, ...
        'VariableNames',{'Test','Beregnet','MaksAbsFejl','Bestaaet'});
end
