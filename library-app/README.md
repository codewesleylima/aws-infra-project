# Library App

Este diretório contém a aplicação Spring Boot para gerenciar a biblioteca de livros.

## Executar localmente

```bash
cd library-app
mvn spring-boot:run
```

A API ficará disponível em `http://localhost:8080`.

## Endpoints

- `GET /api/books` - lista todos os livros
- `GET /api/books/{id}` - consulta um livro por ID
- `POST /api/books` - cria um novo livro
- `PUT /api/books/{id}` - atualiza um livro existente
- `DELETE /api/books/{id}` - remove um livro

## Build

```bash
cd library-app
mvn package
```

## Testes

```bash
cd library-app
mvn test
```
