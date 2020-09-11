# A demonstration of decryption using the RSA scheme in Python
# Author: Fan Bu

# extended GCD
def egcd(a, b):
    if a == 0:
        return (b, 0, 1)
    else:
        gcd, k, l = egcd(b%a, a)
        return (gcd, l-(b//a*k), k)

def modular_inverse(E, phi_N):
    gcd, k, l = egcd(E, phi_N)
    if gcd == 1:
        return (k % phi_N)
    return "Error!"

def modular_pow(B, E, N):
    if E == 0:
        return 1
    B = B%N
    half_E = E//2
    if E % 2 == 0:
        return modular_pow(B*B, half_E, N) % N
    else:
        return (modular_pow(B*B, half_E, N) * B) % N

def RSA_decrypt(P, Q, E, C):
    N = P * Q
    phi_N = (P - 1) * (Q - 1)
    E_inverse = modular_inverse(E, phi_N)
    M = modular_pow(C, E_inverse, N)
    text = ""
    while M != 0:
        digit = M % 27
        if digit == 0:
            text = " "+text
        else:
            text = chr(digit+96)+text
        M = M//27
    return text

P = 435958568325940791799951965387214406385470910265220196318705482144524085345275999740244625255428455944579
Q = 562545761726884103756277007304447481743876944007510545104946851094548396577479473472146228550799322939273
E = 7
C = 163077576587089932277514178989798339755826189700674110151160860819557757512053108465634676999401755817425637794522932574265893488854028596522889419543378155476439015236106447427921542963150735762104095795184542

print(RSA_decrypt(P, Q, E, C))