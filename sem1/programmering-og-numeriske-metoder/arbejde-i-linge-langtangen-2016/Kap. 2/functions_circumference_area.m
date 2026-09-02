r = input("Indtast radius og tryk enter.")

function circumference = C(r)
   circumference = 2*pi*r;
end

function area_c = A_c(r)
    area_c = r^2 * pi;
end

C(r)
A_c(r)