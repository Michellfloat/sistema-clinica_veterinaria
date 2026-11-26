package br.com.clinicavet.util;
/** UtilitÃ¡rios de CPF: limpeza, validaÃ§Ã£o dos dÃ­gitos verificadores e mÃ¡scara (LGPD). */
public final class CpfUtil {
    private CpfUtil() {}
    public static String limpar(String cpf) {
        return cpf == null ? "" : cpf.replaceAll("\\D", "");
    }
    public static boolean valido(String cpf) {
        String n = limpar(cpf);
        if (n.length() != 11 || n.chars().distinct().count() == 1) return false;
        return digito(n, 9) == n.charAt(9) - '0' && digito(n, 10) == n.charAt(10) - '0';
    }
    private static int digito(String n, int tamanho) {
        int soma = 0;
        for (int i = 0; i < tamanho; i++) {
            soma += (n.charAt(i) - '0') * (tamanho + 1 - i);
        }
        int resto = (soma * 10) % 11;
        return resto == 10 ? 0 : resto;
    }
    /** Exibe apenas o miolo: ***.456.789-** */
    public static String mascarar(String cpf) {
        String n = limpar(cpf);
        if (n.length() != 11) return "***.***.***-**";
        return "***." + n.substring(3, 6) + "." + n.substring(6, 9) + "-**";
    }
}