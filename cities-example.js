'use strict';

const Fiber   = require('fibers');
const Neo4jDB = require('neo4j-fiber').Neo4jDB;

Fiber(function () {
  const db = new Neo4jDB('http://localhost:7474', {
    username: 'neo4j',
    password: '1234'
  });

  // Create some data:
  const cities = {};
  cities['Zürich'] = db.nodes({
    title: 'Zürich',
    lat: 47.27,
    long: 8.31
  }).label(['City']);

  cities['Tokyo'] = db.nodes({
    title: 'Tokyo',
    lat: 35.40,
    long: 139.45
  }).label(['City']);

  cities['Athens'] = db.nodes({
    title: 'Athens',
    lat: 37.58,
    long: 23.43
  }).label(['City']);

  cities['Cape Town'] = db.nodes({
    title: 'Cape Town',
    lat: 33.55,
    long: 18.22
  }).label(['City']);


  // Add relationship between cities
  // At this example we set distance
  cities['Zürich'].to(cities['Tokyo'], "DISTANCE", {m: 9576670, km: 9576.67, mi: 5950.67});
  cities['Tokyo'].to(cities['Zürich'], "DISTANCE", {m: 9576670, km: 9576.67, mi: 5950.67});

  // Create route 1 (Zürich -> Athens -> Cape Town -> Tokyo)
  cities['Zürich'].to(cities['Athens'], "ROUTE", {m: 1617270, km: 1617.27, mi: 1004.93, price: 50});
  cities['Athens'].to(cities['Cape Town'], "ROUTE", {m: 8015080, km: 8015.08, mi: 4980.34, price: 500});
  cities['Cape Town'].to(cities['Tokyo'], "ROUTE", {m: 9505550, km: 9505.55, mi: 5906.48, price: 850});

  // Create route 2 (Zürich -> Cape Town -> Tokyo)
  cities['Zürich'].to(cities['Cape Town'], "ROUTE", {m: 1617270, km: 1617.27, mi: 1004.93, price: 550});
  cities['Cape Town'].to(cities['Tokyo'], "ROUTE", {m: 9576670, km: 9576.67, mi: 5950.67, price: 850});

  // Create route 3 (Zürich -> Athens -> Tokyo)
  cities['Zürich'].to(cities['Athens'], "ROUTE", {m: 1617270, km: 1617.27, mi: 1004.93, price: 50});
  cities['Athens'].to(cities['Tokyo'], "ROUTE", {m: 9576670, km: 9576.67, mi: 5950.67, price: 850});

  // Get Shortest Route (in km) between two Cities:
  const shortest  = cities['Zürich'].path(cities['Tokyo'], "ROUTE", {cost_property: 'km', algorithm: 'dijkstra'})[0];
  let shortestStr = 'Shortest from Zürich to Tokyo, via: ';
  shortest.nodes.forEach((id) => {
    shortestStr += db.nodes(id).property('title') + ', ';
  });

  shortestStr += '| Distance: ' + shortest.weight + ' km';
  console.info(shortestStr);

  // Get Cheapest Route (in notional currency) between two Cities:
  const cheapest  = cities['Zürich'].path(cities['Tokyo'], "ROUTE", {cost_property: 'price', algorithm: 'dijkstra'})[0];
  let cheapestStr = 'Cheapest from Zürich to Tokyo, via: ';
  cheapest.nodes.forEach((id) => {
    cheapestStr += db.nodes(id).property('title') + ', ';
  });

  cheapestStr += '| Price: ' + cheapest.weight + ' nc';
  console.info(cheapestStr);
}).run();
