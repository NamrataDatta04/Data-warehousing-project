#!/usr/bin/env python3
"""Export the reporting tables to CSV and draw the README charts.

Run after `dbt build`. Reads warehouse/kereru.duckdb, writes reports/*.csv and docs/img/*.png.
With --export-star it also writes the star schema to exports/*.parquet for Power BI or Tableau.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

BLUE, ORANGE, INK, MUTED, GRID, SURFACE = "#2a78d6", "#eb6834", "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"
REPORTS = ["rpt_store_scorecard", "rpt_trade_discount_leakage", "rpt_sales_rollup", "rpt_stockout_impact",
           "rpt_customer_segments", "rpt_cohort_retention", "rpt_margin_by_price_version", "rpt_monthly_trend",
           "rpt_data_quality"]
STAR = ["dim_date", "dim_store", "dim_product", "dim_customer", "dim_supplier", "fct_sales",
        "fct_inventory_monthly", "fct_store_pnl_quarterly"]

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "font.size": 10, "text.color": INK, "axes.labelcolor": MUTED, "xtick.color": MUTED, "ytick.color": MUTED,
    "axes.edgecolor": GRID, "axes.spines.top": False, "axes.spines.right": False, "axes.spines.left": False,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "axes.axisbelow": True,
    "axes.titlesize": 12, "axes.titleweight": "bold", "axes.titlelocation": "left", "legend.frameon": False,
})
millions = FuncFormatter(lambda v, _: f"${v / 1e6:.1f}M")
thousands = FuncFormatter(lambda v, _: f"{'-' if v < 0 else ''}${abs(v) / 1e3:,.0f}k")


def save(fig, path: Path) -> None:
    fig.tight_layout()
    fig.savefig(path, dpi=160)
    plt.close(fig)


def chart_as_reported(df, out):
    df = df.sort_values("net_sales_excl_gst")
    fig, ax = plt.subplots(figsize=(8, 5.2))
    y = range(len(df))
    ax.barh([i + 0.2 for i in y], df.sales_as_reported, height=0.36, color=ORANGE, label="As reported today (files stacked and summed)")
    ax.barh([i - 0.2 for i in y], df.net_sales_excl_gst, height=0.36, color=BLUE, label="Warehouse: net sales excl. GST")
    for i, (rep, pct) in enumerate(zip(df.sales_as_reported, df.overstated_pct)):
        ax.text(rep + 30000, i + 0.2, f"+{pct:.0f}%", va="center", fontsize=8.5, color=MUTED)
    ax.set_yticks(list(y), df.store_code + "  " + df.city)
    ax.xaxis.set_major_formatter(millions)
    ax.grid(axis="y", visible=False)
    ax.set_title("Two-year sales by store: today's figures overstate every store,\nand by different amounts")
    ax.legend(loc="lower right", fontsize=8.5)
    save(fig, out / "sales_as_reported_vs_warehouse.png")


def chart_net_profit(df, out):
    df = df.sort_values("net_sales_excl_gst", ascending=False)
    fig, ax = plt.subplots(figsize=(8, 4.2))
    ax.bar(df.store_code, df.net_profit, width=0.6, color=BLUE)
    for x, v in zip(df.store_code, df.net_profit):
        ax.text(x, v + (9000 if v >= 0 else -9000), f"{v / 1e3:+,.0f}k", ha="center",
                va="bottom" if v >= 0 else "top", fontsize=8.5, color=INK)
    ax.axhline(0, color=MUTED, linewidth=0.8)
    ax.yaxis.set_major_formatter(thousands)
    ax.grid(axis="x", visible=False)
    ax.set_ylim(df.net_profit.min() - 45000, df.net_profit.max() + 35000)
    ax.set_title("Two-year net profit, stores ordered by sales (largest first):\nthe biggest store loses money")
    save(fig, out / "net_profit_by_store.png")


def chart_stockouts(df, out):
    top = df.groupby("supplier_name").estimated_lost_sales.sum().sort_values(ascending=False).head(5).index
    piv = (df[df.supplier_name.isin(top)].pivot(index="supplier_name", columns="island",
                                                 values="lost_pct_of_potential_sales").loc[top[::-1]])
    fig, ax = plt.subplots(figsize=(8, 3.8))
    y = range(len(piv))
    ax.barh([i + 0.2 for i in y], piv["South Island"], height=0.36, color=ORANGE, label="South Island stores")
    ax.barh([i - 0.2 for i in y], piv["North Island"], height=0.36, color=BLUE, label="North Island stores")
    for i, (s, n) in enumerate(zip(piv["South Island"], piv["North Island"])):
        ax.text(s + 0.5, i + 0.2, f"{s:.0f}%", va="center", fontsize=8.5, color=MUTED)
        ax.text(n + 0.5, i - 0.2, f"{n:.0f}%", va="center", fontsize=8.5, color=MUTED)
    lead = df.drop_duplicates("supplier_name").set_index("supplier_name").lead_time_days
    ax.set_yticks(list(y), [f"{s}\n({lead[s]}-day lead time)" for s in piv.index], fontsize=8.5)
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:.0f}%"))
    ax.grid(axis="y", visible=False)
    ax.set_title("Estimated sales lost to stockouts, as a share of potential sales")
    ax.legend(loc="lower right", fontsize=8.5)
    save(fig, out / "stockout_lost_sales.png")


def chart_trend(df, out):
    fig, ax = plt.subplots(figsize=(8, 3.8))
    ax.plot(df.month_start, df.net_sales_excl_gst, color=BLUE, linewidth=2, marker="o", markersize=4, label="Monthly net sales excl. GST")
    ax.plot(df.month_start, df.moving_average_3_months, color=ORANGE, linewidth=2, label="Three-month moving average")
    ax.yaxis.set_major_formatter(millions)
    ax.set_ylim(0, df.net_sales_excl_gst.max() * 1.15)
    ax.grid(axis="x", visible=False)
    ax.set_title("Co-op monthly sales peak every spring and early summer")
    ax.legend(loc="lower right", fontsize=8.5)
    save(fig, out / "monthly_sales_trend.png")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--db", default="warehouse/kereru.duckdb")
    ap.add_argument("--export-star", action="store_true", help="also write the star schema to exports/*.parquet")
    args = ap.parse_args()
    con = duckdb.connect(args.db, read_only=True)
    reports, img = Path("reports"), Path("docs/img")
    reports.mkdir(exist_ok=True)
    img.mkdir(parents=True, exist_ok=True)

    frames = {}
    for name in REPORTS:
        frames[name] = con.sql(f"select * from reporting.{name}").df()
        frames[name].to_csv(reports / f"{name.removeprefix('rpt_')}.csv", index=False)
    chart_as_reported(frames["rpt_store_scorecard"], img)
    chart_net_profit(frames["rpt_store_scorecard"], img)
    chart_stockouts(frames["rpt_stockout_impact"], img)
    chart_trend(frames["rpt_monthly_trend"], img)
    print(f"Wrote {len(REPORTS)} CSV reports to {reports}/ and 4 charts to {img}/")

    if args.export_star:
        exports = Path("exports")
        exports.mkdir(exist_ok=True)
        for table in STAR:
            con.sql(f"copy core.{table} to '{exports / table}.parquet' (format parquet)")
        print(f"Wrote {len(STAR)} star-schema tables to {exports}/")


if __name__ == "__main__":
    main()
