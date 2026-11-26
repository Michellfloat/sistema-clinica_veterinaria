package br.com.clinicavet.exception;
public class BusinessException extends RuntimeException {
    public BusinessException(String mensagem) { super(mensagem); }
}