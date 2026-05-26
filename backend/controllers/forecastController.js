const forecastService = require("../services/forecastService");
const catchAsync = require("../utils/catchAsync");

exports.getForecast = catchAsync(async (req, res, next) => {
  const data = await forecastService.getForecast(req.userId);

  res.status(200).json({
    status: "success",
    data,
  });
});
