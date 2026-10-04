/* Flutter sends JSON commands through receive(). The chart and series live
   for the lifetime of this page, including quote updates and timeframe swaps. */
(() => {
  const L = window.LightweightCharts;
  const host = document.getElementById('chart');
  const rose = '#f8eaea';
  const up = '#347fce';
  const down = '#d94c56';
  let referenceAxes = false;
  let gridEnabled = true;
  const formatTick = (time) => referenceAxes ? '' : new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Bangkok', hour: '2-digit', minute: '2-digit',
  }).format(new Date(time * 1000));
  const chart = L.createChart(host, {
    width: host.clientWidth,
    height: host.clientHeight,
    layout: {
      background: { type: L.ColorType.Solid, color: 'rgba(0,0,0,0)' },
      textColor: '#879099',
      fontFamily: '-apple-system, BlinkMacSystemFont, Roboto, sans-serif',
      fontSize: 10,
      attributionLogo: false,
    },
    grid: {
      vertLines: { color: '#ecdede', visible: true },
      horzLines: { color: '#ecdede', visible: true },
    },
    rightPriceScale: {
      borderVisible: false,
      tickMarkDensity: 9,
      scaleMargins: { top: 0.072, bottom: 0.038 },
    },
    leftPriceScale: { visible: false },
    timeScale: {
      borderVisible: false,
      timeVisible: true,
      secondsVisible: false,
      barSpacing: 3.7,
      rightOffset: 27.3,
      tickMarkFormatter: (time) => formatTick(time),
      fixLeftEdge: false,
      fixRightEdge: false,
    },
    crosshair: {
      mode: L.CrosshairMode.Normal,
      vertLine: { color: '#a8afb8', style: L.LineStyle.Dashed, labelBackgroundColor: '#767c85' },
      horzLine: { color: '#a8afb8', style: L.LineStyle.Dashed, labelBackgroundColor: '#767c85' },
    },
    handleScroll: { mouseWheel: true, pressedMouseMove: true, horzTouchDrag: true, vertTouchDrag: false },
    handleScale: { pinch: true, mouseWheel: true, axisPressedMouseMove: true },
    localization: { locale: 'en-US', timeFormatter: (time) => {
      const d = new Date(time * 1000);
      return new Intl.DateTimeFormat('vi-VN', { timeZone: 'Asia/Bangkok', hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' }).format(d);
    } },
  });
  const attribution = host.querySelector('#tv-attr-logo');
  if (attribution) attribution.target = '_self';
  const candle = chart.addSeries(L.CandlestickSeries, {
    upColor: up, downColor: down, wickUpColor: up, wickDownColor: down,
    borderVisible: false,
    priceFormat: { type: 'price', precision: 3, minMove: 0.001 },
    priceLineVisible: false,
    lastValueVisible: false,
  });
  let bidLine;
  let askLine;
  let bars = [];
  let displayMode = 'candles';
  let lineSeries;
  const referenceTicks = [
    { time: Date.UTC(2026, 8, 20, 20, 8) / 1000, label: '03:08' },
    { time: Date.UTC(2026, 8, 20, 20, 58) / 1000, label: '03:58' },
  ];
  host.style.position = 'relative';
  const referenceGuides = document.createElement('div');
  referenceGuides.style.cssText = 'position:absolute;inset:0;pointer-events:none;overflow:hidden';
  host.appendChild(referenceGuides);
  const updateReferenceGuides = () => {
    referenceGuides.replaceChildren();
    if (!referenceAxes || !bars.length) return;
    const paneHeight = host.clientHeight - chart.timeScale().height();
    for (const tick of referenceTicks) {
      const coordinate = chart.timeScale().timeToCoordinate(tick.time);
      if (coordinate === null || coordinate < 0 || coordinate > host.clientWidth) continue;
      const x = Math.round(coordinate + 4);
      if (gridEnabled) {
        const line = document.createElement('div');
        line.style.cssText = `position:absolute;left:${x}px;top:0;width:1px;height:${paneHeight}px;background:#eee0e0`;
        referenceGuides.appendChild(line);
      }
      const label = document.createElement('div');
      label.textContent = tick.label;
      label.style.cssText = `position:absolute;left:${x}px;top:${paneHeight + 10}px;transform:translateX(-50%);color:#879099;font:10px Roboto,sans-serif;white-space:nowrap`;
      referenceGuides.appendChild(label);
    }
  };
  const stopReferenceAxes = () => {
    if (!referenceAxes) return;
    referenceAxes = false;
    chart.applyOptions({ grid: { vertLines: { visible: gridEnabled } } });
    chart.timeScale().applyOptions({ tickMarkFormatter: formatTick });
    updateReferenceGuides();
  };
  host.addEventListener('pointerdown', stopReferenceAxes);
  host.addEventListener('wheel', stopReferenceAxes);
  chart.timeScale().subscribeVisibleLogicalRangeChange(updateReferenceGuides);
  const asBar = (item) => ({
    time: item.time,
    open: item.open,
    high: item.high,
    low: item.low,
    close: item.close,
  });
  const applyData = () => {
    if (displayMode === 'line') {
      candle.setData([]);
      if (!lineSeries) lineSeries = chart.addSeries(L.LineSeries, {
        color: up, lineWidth: 2, priceFormat: { type: 'price', precision: 3, minMove: 0.001 },
        priceLineVisible: false, lastValueVisible: false,
      });
      lineSeries.setData(bars.map((item) => ({ time: item.time, value: item.close })));
    } else {
      if (lineSeries) lineSeries.setData([]);
      candle.setData(bars);
    }
  };
  const priceLine = (old, price, color, width = 1) => {
    if (old) candle.removePriceLine(old);
    if (typeof price !== 'number' || !Number.isFinite(price)) return undefined;
    return candle.createPriceLine({
      price, color, lineWidth: width, lineStyle: L.LineStyle.Dotted,
      axisLabelVisible: true, title: '',
      axisLabelColor: color, axisLabelTextColor: '#fff',
    });
  };
  window.exnessChart = {
    receive(message) {
      switch (message.type) {
        case 'setData':
          bars = message.candles.map(asBar);
          applyData();
          chart.timeScale().applyOptions({ barSpacing: 3.7, rightOffset: 27.3 });
          chart.timeScale().scrollToRealTime();
          requestAnimationFrame(updateReferenceGuides);
          break;
        case 'updateCandle': {
          const next = asBar(message.candle);
          if (bars.length && next.time === bars[bars.length - 1].time) bars[bars.length - 1] = next;
          else if (!bars.length || next.time > bars[bars.length - 1].time) bars.push(next);
          if (displayMode === 'line') lineSeries.update({ time: next.time, value: next.close });
          else candle.update(next);
          break;
        }
        case 'setQuote':
          bidLine = priceLine(bidLine, message.visible === false ? null : message.bid,
            down, message.source === 'bid' ? 2 : 1);
          askLine = priceLine(askLine, message.visible === false ? null : message.ask,
            up, message.source === 'ask' ? 2 : 1);
          break;
        case 'setStyle':
          gridEnabled = message.grid !== false;
          referenceAxes = message.videoReferenceAxes === true;
          document.documentElement.style.setProperty('--pane-bg',
            message.provider === 'TradingView' ? '#ffffff' : rose);
          chart.applyOptions({
            grid: {
              vertLines: { visible: gridEnabled && !referenceAxes },
              horzLines: { visible: gridEnabled },
            },
          });
          chart.timeScale().applyOptions({
            visible: message.timeScale !== false,
            tickMarkFormatter: formatTick,
          });
          chart.priceScale('right').applyOptions({ visible: message.priceScale !== false });
          requestAnimationFrame(updateReferenceGuides);
          if (message.priceLines === false) {
            bidLine = priceLine(bidLine, null, down);
            askLine = priceLine(askLine, null, up);
          }
          break;
        case 'setDisplayMode':
          displayMode = message.mode;
          applyData();
          break;
        case 'resetView':
          chart.timeScale().applyOptions({ barSpacing: 3.7, rightOffset: 27.3 });
          chart.timeScale().scrollToRealTime();
          break;
      }
    },
  };
  new ResizeObserver(() => {
    chart.resize(host.clientWidth, host.clientHeight);
    requestAnimationFrame(updateReferenceGuides);
  }).observe(host);
  if (window.ChartBridge) window.ChartBridge.postMessage('ready');
})();
