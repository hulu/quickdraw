declare module "@hulu/quickdraw" {
    function isObservable<T>(obj: any): obj is Observable<T>;
    function observable<T>(obj?: T): Observable<T>;
    function observableArray<T>(obj?: T[]): ObservableArray<T>;
    function computed<T>(func: () => T, bindingContext: any, dependencies: Observable<any>[]): Observable<T>;
    function removeListener(type: string, callback: Function): void;
    function once(name: string, callback: Function): void;
    function unwrapObservable<T>(obs: Observable<T> | T, recursive?: boolean): T;
    function bindModel(model: any, node: HTMLElement): void;
    function unbindModel(model: any): void;
    function on(hasOccured?: string, _checkAgain?: () => void): void;

    /** Registers a binding handler with quickdraw, allowing data bindings to be used in templates */
    function registerBindingHandler(
        name: string,
        callbacks: BindingHandler,
        dependencies?: string[],
        override?: boolean
    ): void;

    interface BindingHandler {
        initialize?(bindingData?: any, node?: any, bindingContext?: any): boolean | void;
        cleanup?: Function;
        update?: Function;
    }

    interface Observable<T> {
        (): T;
        (value: T): void;
        isBound(): boolean;
        on(event: string, callback: Function): void;
        addComputedDependency(obs: Observable<T>): void;
        immediate(value: T): void;
    }

    interface ObservableArray<T> {
        (): T[];
        (val: T[]): void;
        push(val: T): void;
        unshift(val: T): void;
        pop(): T;
        on(event: string, callback: Function): void;
        [key: number]: T;
        splice(start: number, deleteCount?: number, ...replacements: T[]): T[];
        remove(val: T): void;
        removeAll(): void;
    }

    interface Computed<T> extends Observable<T> {
        (): T;
    }
}
