function Q = QMat(E1, E2, G12, nu12)
    nu21 = nu12 * E2 / E1;
    
    denom = 1 - nu12 * nu21;
    
    Q = zeros(3,3);
    
    Q(1,1) = E1 / denom;
    Q(2,2) = E2 / denom;
    Q(1,2) = nu12 * E2 / denom;
    Q(2,1) = Q(1,2);
    Q(3,3) = G12;
end