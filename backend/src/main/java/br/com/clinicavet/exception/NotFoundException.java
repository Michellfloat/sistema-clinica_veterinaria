package br.com.clinicavet.exception;
public class NotFoundException extends RuntimeException {
    public NotFoundException(String mensagem) { super(mensagem); }
}