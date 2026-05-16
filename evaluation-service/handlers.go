package main

import (
	"context"
	"encoding/json"
	"net/http"
)

type EvaluationResponse struct {
	FlagName string `json:"flag_name"`
	UserID   string `json:"user_id"`
	Result   bool   `json:"result"`
}

func (a *App) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(map[string]string{"status": "ok"}); err != nil {
		logCtx(r.Context(), "Erro ao codificar resposta health: %v", err)
	}
}

func (a *App) evaluationHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	w.Header().Set("Content-Type", "application/json")

	userID := r.URL.Query().Get("user_id")
	flagName := r.URL.Query().Get("flag_name")

	if userID == "" || flagName == "" {
		http.Error(w, `{"error": "user_id e flag_name são obrigatórios"}`, http.StatusBadRequest)
		return
	}

	result, err := a.getDecision(ctx, userID, flagName)
	if err != nil {
		if _, ok := err.(*NotFoundError); ok {
			result = false
		} else {
			logCtx(ctx, "Erro ao avaliar flag '%s': %v", sanitize(flagName), err)
			http.Error(w, `{"error": "Erro interno ao avaliar a flag"}`, http.StatusBadGateway)
			return
		}
	}

	go a.sendEvaluationEvent(context.WithoutCancel(ctx), userID, flagName, result)

	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(EvaluationResponse{
		FlagName: flagName,
		UserID:   userID,
		Result:   result,
	}); err != nil {
		logCtx(ctx, "Erro ao codificar resposta de avaliação: %v", err)
	}
}
