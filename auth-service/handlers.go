package main

import (
	"encoding/json"
	"net/http"
	"strings"
)

type CreateKeyRequest struct {
	Name string `json:"name"`
}

type CreateKeyResponse struct {
	Name    string `json:"name"`
	Key     string `json:"key"`
	Message string `json:"message"`
}

func (a *App) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(map[string]string{"status": "ok"}); err != nil {
		logCtx(r.Context(), "Erro ao codificar resposta health: %v", err)
	}
}

func (a *App) validateKeyHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	authHeader := r.Header.Get("Authorization")
	keyString := strings.TrimPrefix(authHeader, "Bearer ")

	if keyString == "" {
		http.Error(w, "Authorization header não encontrado", http.StatusUnauthorized)
		return
	}

	keyHash := hashAPIKey(keyString)

	var id int
	err := a.DB.QueryRowContext(ctx, "SELECT id FROM api_keys WHERE key_hash = $1 AND is_active = true", keyHash).Scan(&id)
	if err != nil {
		logCtx(ctx, "Falha na validação da chave (hash: %s...): %v", keyHash[:6], err)
		http.Error(w, "Chave de API inválida ou inativa", http.StatusUnauthorized)
		return
	}

	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(map[string]string{"message": "Chave válida"}); err != nil {
		logCtx(ctx, "Erro ao codificar resposta de validação: %v", err)
	}
}

func (a *App) createKeyHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if r.Method != http.MethodPost {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	var req CreateKeyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Corpo da requisição inválido", http.StatusBadRequest)
		return
	}

	if req.Name == "" {
		http.Error(w, "O campo 'name' é obrigatório", http.StatusBadRequest)
		return
	}

	newKey, err := generateAPIKey()
	if err != nil {
		http.Error(w, "Erro ao gerar a chave", http.StatusInternalServerError)
		return
	}
	newKeyHash := hashAPIKey(newKey)

	var newID int
	err = a.DB.QueryRowContext(ctx,
		"INSERT INTO api_keys (name, key_hash) VALUES ($1, $2) RETURNING id",
		req.Name, newKeyHash,
	).Scan(&newID)

	if err != nil {
		logCtx(ctx, "Erro ao salvar a chave no banco: %v", err)
		http.Error(w, "Erro ao salvar a chave", http.StatusInternalServerError)
		return
	}

	logCtx(ctx, "Nova chave criada com sucesso (ID: %d, Name: %s)", newID, req.Name)
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(CreateKeyResponse{
		Name:    req.Name,
		Key:     newKey,
		Message: "Guarde esta chave com segurança! Você não poderá vê-la novamente.",
	}); err != nil {
		logCtx(ctx, "Erro ao codificar resposta de criação: %v", err)
	}
}

func (a *App) masterKeyAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		keyString := strings.TrimPrefix(authHeader, "Bearer ")

		if keyString != a.MasterKey {
			http.Error(w, "Acesso não autorizado", http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}
