#!/usr/bin/env python3

# Das zu prüfende Array aus deinem Bash-Skript
sizes = [
    # Start
    "4098,1026",
    "6146,1538",
    "8194,2050",
    "10242,2562",
    "12802,3202",
    # Mitte
    "16386,4098",
    "20482,5122",
    "24578,6146",
    "32770,8194",
    "40962,10242",
    # Hoch
    "49154,12290",
    "65538,16386",
    "81922,20482",
    "98306,24578",
    "131074,32770",
    # Max
    "163842,40962",
    "196610,49154",
    "229378,57346",
    "262146,65538",
]

# Deine 5 MPI-Topologien
topologies = [(16, 1), (8, 2), (4, 4), (2, 8), (1, 16)]


def verify_sizes():
    print(
        f"{'Grid (nx, ny)':<18} | {'(nx-2, ny-2)':<18} | {'Ratio':<7} | {'Topos (16x1..1x16)':<18} | Status"
    )
    print("-" * 75)

    all_valid = True

    for entry in sizes:
        nx, ny = map(int, entry.split(","))

        # Nutzzellen (ohne Halo / Rand)
        nx_inner = nx - 2
        ny_inner = ny - 2

        # 1. Ratio Check
        ratio = nx_inner / ny_inner
        ratio_valid = abs(ratio - 4.0) < 1e-9

        # 2. Topologie-Teilbarkeit Check
        topo_results = []
        size_valid = True

        for px, py in topologies:
            div_x = nx_inner % px == 0
            div_y = ny_inner % py == 0

            if not (div_x and div_y):
                size_valid = False
                topo_results.append("FAIL")
            else:
                topo_results.append("OK")

        # 3. Geradlinigkeit Check
        even_valid = (nx % 2 == 0) and (ny % 2 == 0)

        total_valid = ratio_valid and size_valid and even_valid
        if not total_valid:
            all_valid = False

        status_str = "✅ PASS" if total_valid else "❌ FAIL"
        topo_str = f"[{'/'.join(topo_results)}]"

        print(
            f"{entry:<18} | {f'({nx_inner}, {ny_inner})':<18} | {ratio:<7.2f} | {topo_str:<18} | {status_str}"
        )

    print("-" * 75)
    if all_valid:
        print(
            "🎉 ERFOLG: Alle Gittergrößen erfüllen die Bedingungen für ALLE Topologien!"
        )
    else:
        print("⚠️ FEHLER: Einige Gittergrößen verletzen die Bedingungen!")


if __name__ == "__main__":
    verify_sizes()