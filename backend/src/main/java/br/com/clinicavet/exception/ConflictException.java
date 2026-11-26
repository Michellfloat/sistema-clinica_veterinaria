package br.com.clinicavet.exception;
public class ConflictException extends RuntimeException {
    public ConflictException(String mensagem) { super(mensagem); }
}