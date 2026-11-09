// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
)

// GatewayRules is the policy's [gateway] table: what the local AI gateway
// (dot-ai-serve) lets a request use, checked before the engine sees it.
// Models is an allow-list of globs over the model the request resolves to
// (an alias such as haiku, or an id); empty allows every model.
// MaxInputTokens caps the gateway's estimate of a request's input; 0 is no
// cap.
type GatewayRules struct {
	Models         []string `toml:"models"`
	MaxInputTokens int      `toml:"max_input_tokens"`
}

func (g GatewayRules) validate() error {
	for _, pat := range g.Models {
		if pat == "" {
			return errors.New("gateway.models: an empty pattern")
		}
	}
	if g.MaxInputTokens < 0 {
		return fmt.Errorf("gateway.max_input_tokens: %d is below 0", g.MaxInputTokens)
	}
	return nil
}

// DecideRequest is why the gateway must refuse a request for model with
// about tokens of input, or "" to let it through.
func DecideRequest(g GatewayRules, model string, tokens int) string {
	if len(g.Models) > 0 && !matchAny(g.Models, model, false, nil) {
		return fmt.Sprintf("model %q is not in gateway.models", model)
	}
	if g.MaxInputTokens > 0 && tokens > g.MaxInputTokens {
		return fmt.Sprintf("about %d input tokens, over gateway.max_input_tokens (%d)", tokens, g.MaxInputTokens)
	}
	return ""
}

// runGateway is `dot-policy gateway --model M --input-tokens N`: exit 0
// lets the request through; exit 1 refuses it, with the reason on stdout.
// It fails closed: a policy that does not load refuses every request.
func runGateway(args []string, out, errw io.Writer, getenv func(string) string) int {
	var o opts
	var model string
	var tokens int
	fs := flag.NewFlagSet("gateway", flag.ContinueOnError)
	fs.SetOutput(errw)
	fs.StringVar(&model, "model", "", "the model the request resolves to")
	fs.IntVar(&tokens, "input-tokens", 0, "the gateway's estimate of its input tokens")
	fs.StringVar(&o.policy, "policy", "", "policy file")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if fs.NArg() > 0 {
		fmt.Fprintf(errw, "dot-policy gateway: unexpected argument %q\n", fs.Arg(0))
		return 2
	}
	path := policyPath(o, getenv)
	p, err := LoadPolicy(path)
	if errors.Is(err, ErrNoPolicy) {
		return 0
	}
	if err != nil {
		fmt.Fprintf(out, "dot ai policy: %s is invalid (%v); every request is refused until it is fixed (dot ai policy check)\n", path, err)
		return 1
	}
	if why := DecideRequest(p.Gateway, model, tokens); why != "" {
		fmt.Fprintf(out, "dot ai policy: %s\n", why)
		return 1
	}
	return 0
}
