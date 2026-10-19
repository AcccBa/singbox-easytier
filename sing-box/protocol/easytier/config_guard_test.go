//go:build with_easytier

package easytier

import (
	"context"
	"strings"
	"testing"

	"github.com/sagernet/sing-box/option"
)

// Both cases return from NewOutbound before the wasm host is touched, so a nil
// router and logger are fine here. The guard is worth pinning as a test rather
// than by review: if it goes away, `config_toml` silently swallows the
// structured fields, which is a muted failure (a node joins nothing and the
// config still looks valid) that only shows up as "why is this peer missing".

func TestEasyTierConfigGuardRequiresNetworkName(t *testing.T) {
	t.Parallel()
	_, err := NewOutbound(context.Background(), nil, nil, "easytier", option.EasyTierOutboundOptions{})
	if err == nil {
		t.Fatal("config with neither network_name nor config_toml must be rejected")
	}
	if !strings.Contains(err.Error(), "network_name") {
		t.Errorf("error must name the missing field, got: %v", err)
	}
}

func TestEasyTierConfigGuardRejectsConfigTOMLConflict(t *testing.T) {
	t.Parallel()
	_, err := NewOutbound(context.Background(), nil, nil, "easytier", option.EasyTierOutboundOptions{
		ConfigTOML:    "[instance]\nhostname = \"x\"\n",
		NetworkName:   "example-net",
		NetworkSecret: "example-secret",
	})
	if err == nil {
		t.Fatal("config_toml alongside structured fields must error, not silently override them")
	}
	msg := err.Error()
	if !strings.Contains(msg, "config_toml") || !strings.Contains(msg, "network_name") {
		t.Errorf("error must name both sides of the conflict, got: %v", msg)
	}
}
