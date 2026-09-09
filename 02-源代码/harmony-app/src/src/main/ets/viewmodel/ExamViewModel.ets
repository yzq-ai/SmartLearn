export class ExamViewModel {
  public id: number = 0;
  public title: string = '';
  public durationMin: number = 60;
  public status: string = '';
  public score: number | undefined = undefined;
  public total: number | undefined = undefined;

  static of(id: number, title: string, durationMin: number): ExamViewModel {
    const vm: ExamViewModel = new ExamViewModel();
    vm.id = id;
    vm.title = title;
    vm.durationMin = durationMin;
    return vm;
  }
}
