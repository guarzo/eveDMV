# Module Tags & Metrics

## Module Tags from wanderer-kills

Module tags are high-level descriptors extracted from the full fitting detail. They let us filter on broad categories without parsing every module string.

| Tag | Definition & Examples |
|---|---|
| **T1 / T2 / T3** | Tech level of modules<br/>`["T2 Guns","T3 Armor Repairer"]` |
| **Slot Type** | High, Mid, Low, Rig<br/>`["High Slot","Mid Slot","Low Slot","Rig"]` |
| **Weapon Group** | Hybrid, Projectile, Energy, Drone<br/>`["Hybrid","Projectile","Drone"]` |
| **Support** | Shield Extender, Armor Repairer, Sensor Booster<br/>`["Shield Extender","Armor Repairer","Sensor Booster"]` |
| **Propulsion** | Afterburner, Microwarpdrive, Warp Disruptor<br/>`["Afterburner","Warp Disruptor"]` |

### Extraction Logic (pseudo-Elixir):

```elixir
defmodule Enrichment.Tags do
  @tech_regex ~r/II|I{1,3}/
  @slot_map %{
    high: ["weapon", "launcher"],
    mid:  ["shield", "ew", "propulsion"],
    low:  ["armor", "rig"]
  }

  def extract_tags(fitting_blob) do
    modules = fitting_blob["modules"]  # list of %{type_name, slot, meta_group_name}

    modules
    |> Enum.flat_map(&module_tags/1)
    |> Enum.uniq()
  end

  defp module_tags(%{"type_name" => name, "slot" => slot, "meta_group_name" => meta}) do
    [
      tech_tag(name),
      slot_tag(slot),
      group_tag(meta),
      category_tag(name)
    ]
    |> Enum.filter(& &1)  # drop nils
  end

  defp tech_tag(name) do
    case Regex.run(@tech_regex, name) do
      ["II"] -> "T2"
      ["III"] -> "T3"
      _ -> nil
    end
  end

  defp slot_tag(slot) when slot in ["high","mid","low"], do: String.capitalize(slot) <> " Slot"
  defp slot_tag(_), do: nil

  defp group_tag(meta) when meta in ["Hybrid Weapon","Projectile Weapon","Energy Weapon","Drone"] do
    String.replace(meta, " Weapon", "")
  end
  defp group_tag(_), do: nil

  defp category_tag(name) do
    cond do
      String.contains?(name, "Shield Extender") -> "Shield Extender"
      String.contains?(name, "Armor Repairer") -> "Armor Repairer"
      true -> nil
    end
  end
end
```

## 2. ISK Value Calculation

We want an accurate "loss value" for each killmail:

### Hull Value
Market price (`median_price`) of the destroyed ship type at the kill timestamp.

### Fitting Value
Sum of `quantity × median_price` for each fitted module.

### Total Loss
```elixir
total_isk = hull_price + Enum.sum(for m <- modules, do: m.qty * module_price(m))
```

By default we take the total loss (hull + fitting). If a pilot self-destructs or no fitting data, we fall back to hull only.

## 3. Mass Balance & Usefulness Index

These metrics normalize pilot performance.

### 3.1 Mass Balance

"Share" of destroyed mass minus lost mass, normalized.

**Destroyed mass share:**
- For each killmail, let M = total ship‐and‐fitting mass destroyed (in kg)
- Let N = number of participants on that kill (exclude pods)
- Each participant gets M / N share

**Lost mass:**
- Pod mass and logistics ships are excluded
- Otherwise, destroyed ship mass only

**Balance per pilot:**
```elixir
balance = sum(destroyed_mass_shares for pilot) - sum(lost_mass for pilot)
```

**Normalize:** A "good" pilot has balance ≥ 0; zero means they've neither under-nor over-performed.

### 3.2 Usefulness Index

Ratio of actual share vs. expected share within their organization.

**Org norm:**
- For a corporation of size C, total destroyed mass in 90-day window is T
- Norm per pilot = T / C

**Pilot's actual** = their `sum(destroyed_mass_shares)`

**Usefulness:**
```
usefulness = actual / (T / C)
```

- `1.0` = average participation
- `>1.0` = above-average
- `<1.0` = below-average

## Usage Examples

With these concrete definitions in place you can now:

- Filter on tags like `["T2","Mid Slot","Shield Extender"]`
- Trigger alerts for kills over X ISK using `total_loss`
- Surface "top command pilots" by `usefulness > 1.5`